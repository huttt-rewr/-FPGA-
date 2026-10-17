// FAT32只读：根目录短名枚举、双流簇链映射。SD/SPI/仲裁器保持原样。
// 请求保持至end/error；完成后空拍。取消图片事务时排空当前物理扇区。
module sd_fat32 #(
 parameter integer MAX_BMP=4,parameter integer ROOT_CLUSTER_LIMIT=4096
)(
 input clk,rst,sd_init_done,
 output reg mount_done,mount_error,output reg [3:0] mount_error_code,
 output reg [2:0] bmp_count,output reg wav_found,
 output [MAX_BMP*32-1:0] bmp_size,output reg [31:0] wav_size,
 input bmp_req,input [2:0] bmp_file_idx,input [31:0] bmp_rel_sector,
 output [7:0] bmp_data,output bmp_valid,output reg bmp_end,bmp_error,bmp_grant,
 input aud_req,input [31:0] aud_rel_sector,
 output [7:0] aud_data,output aud_valid,output reg aud_end,aud_error,
 output arb_bmp_req,output [31:0] arb_bmp_addr,
 input [7:0] arb_bmp_data,input arb_bmp_valid,arb_bmp_end,arb_bmp_error,arb_bmp_grant,
 output arb_aud_req,output [31:0] arb_aud_addr,
 input [7:0] arb_aud_data,input arb_aud_valid,arb_aud_end,arb_aud_error,
 input bmp_abort
);
 // 独热编码；几何运算、比较、地址生成分拍完成。
 localparam [43:0] WAIT_INIT=40'h1,BOOT_REQ=40'h2,BOOT_RX=40'h4,
 BOOT_CHECK=40'h8,GEOM1=40'h10,GEOM2=40'h20,GEOM3=40'h40,
 DIR_ADDR=40'h80,DIR_REQ=40'h100,DIR_RX=40'h200,DIR_CHECK=40'h400,
 FAT_ADDR=40'h800,FAT_CHECK=40'h1000,FAT_REQ=40'h2000,FAT_RX=40'h4000,
 FAT_LOOK=40'h8000,FAT_GET=40'h10000,FAT_EVAL=40'h20000,
 IDLE=40'h40000,STREAM_INIT=40'h80000,STREAM_PREP=40'h100000,
 STREAM_ADDR=40'h200000,STREAM_REQ=40'h400000,STREAM_RX=40'h800000,
 STREAM_ERR=40'h1000000,GAP=40'h2000000,FAULT=40'h4000000,GEOM4=40'h8000000,
 GEOM5=40'h10000000,GEOM6=40'h20000000,GEOM7=40'h40000000,
 DIR_SHIFT=40'h80000000,DIR_BASE=40'h100000000,DIR_FINISH=40'h200000000,
 STREAM_LIMIT=40'h400000000,STREAM_SHIFT=40'h800000000,
 STREAM_BASE=40'h1000000000,STREAM_FINISH=40'h2000000000,
 FAT_VALIDATE=40'h4000000000,META_DRAIN=40'h8000000000,
 STREAM_CHECK=41'h10000000000,BOOT_DECIDE=42'h20000000000,
 GEOM_FIELDS=43'h40000000000,FAT_COMMIT=44'h80000000000;
 reg [43:0] state;
 reg owner,mount_fat,bpb_at_partition,dir_ended,cancel_bmp;
 reg [31:0] physical_addr,partition_lba,partition_size,selected_lba;
 reg partition_found;reg [7:0] partition_type;
 reg [31:0] partition_candidate,partition_length;
 reg [31:0] total_sectors,fat_sectors,root_cluster,first_fat,first_data;
 reg [31:0] overhead,data_clusters,max_cluster,volume_last,data_sectors,total_minus_one;
 reg [31:0] map_minus_two,map_shifted,map_base;
 reg [32:0] request_sectors;
 reg [7:0] spc_mask;
 reg geometry_bad,root_bad,fat_capacity_bad,boot_signature_ok,boot_super_ok,boot_partition_ok,geom_fields_bad;
 reg cmp_to,cmp_vol,cmp_lo,cmp_hi;
 reg [15:0] bytes_per_sector,reserved_count,root_entries,fat16_size,ext_flags,fs_version,signature;
 reg [7:0] spc,num_fats;reg [2:0] spc_shift;
 reg [31:0] fat_area;reg [9:0] byte_count;
 reg [31:0] image_cluster[0:MAX_BMP-1],image_size[0:MAX_BMP-1],wav_cluster;
 reg store_bmp,store_wav;reg [2:0] store_index;reg [31:0] store_cluster,store_size;
 localparam integer ROOT_HOP_BITS=(ROOT_CLUSTER_LIMIT<2)?1:$clog2(ROOT_CLUSTER_LIMIT+1);
 reg [31:0] dir_cluster;reg [ROOT_HOP_BITS-1:0] dir_hops;reg [7:0] dir_sector;
 reg [7:0] entry_first,entry_attr,ext0,ext1,ext2;
 reg [31:0] entry_cluster,entry_size;
 // 文件大小为32位字节数，文件内扇区/簇序号最多24位，避免冗余宽计数器。
 reg [31:0] cursor_cluster[0:1];reg [23:0] cursor_index[0:1];
 reg [1:0] cursor_valid;reg [2:0] cursor_file;
 reg [31:0] request_rel,request_size,working_cluster;
 reg [23:0] target_index,working_index;
 reg [2:0] request_file;
 reg [31:0] fat_target,fat_tag[0:1],fat_lba,fat_word,fat_q,next_cluster;
 reg [1:0] fat_valid;reg [6:0] fat_entry;reg [1:0] gap_count;
 (* ram_style="bram" *) reg [31:0] fat_cache[0:255];
 integer i;genvar k;
 generate for(k=0;k<MAX_BMP;k=k+1)begin:sizes
  assign bmp_size[k*32+:32]=image_size[k];
  // 文件描述符独立本地写使能，不让目录过滤/初始化优先级串到128位表。
  always @(posedge clk or posedge rst)begin
   if(rst)begin image_cluster[k]<=0;image_size[k]<=0;end
   else if(store_bmp && store_index==k)begin image_cluster[k]<=store_cluster;image_size[k]<=store_size;end
  end
 end endgenerate
 always @(posedge clk or posedge rst)begin
  if(rst)begin wav_cluster<=0;wav_size<=0;end
  else if(store_wav)begin wav_cluster<=store_cluster;wav_size<=store_size;end
 end
 reg [7:0] disk_data;reg disk_valid,disk_end,disk_error;
 // 物理返回在中间层入口整体寄存，字节/valid/end/error保持同拍。
 // 原仲裁器不变，隔断transport_reset/SD错误到FAT游标的组合反馈。
 always @(posedge clk or posedge rst)begin
  if(rst)begin disk_data<=0;disk_valid<=0;disk_end<=0;disk_error<=0;end
  else begin
   disk_data<=owner?arb_aud_data:arb_bmp_data;
   disk_valid<=sd_init_done && (owner?arb_aud_valid:arb_bmp_valid);
   disk_end<=sd_init_done && (owner?arb_aud_end:arb_bmp_end);
   disk_error<=sd_init_done && (owner?arb_aud_error:arb_bmp_error);
  end
 end
 // 接口直接使用独热位，避免综合器重新编码后增加宽状态比较器。
 wire transferring=state[2] || state[9] || state[14] || state[23];
 wire [10:0] final_count={1'b0,byte_count}+disk_valid;
 reg spc_ok;
 reg cluster_ok,cluster_eoc,cluster_self,stream_bad,fat_rx_bad;
 reg meta_valid,meta_boot,meta_dir;reg [9:0] meta_index;reg [7:0] meta_data;
 assign arb_bmp_req=!owner && transferring;assign arb_aud_req=owner && transferring;
 assign arb_bmp_addr=physical_addr;assign arb_aud_addr=physical_addr;
 assign bmp_data=disk_data;assign aud_data=disk_data;
 assign bmp_valid=state[23] && !owner && disk_valid && !disk_error && !cancel_bmp && !bmp_abort;
 assign aud_valid=state[23] && owner && disk_valid && !disk_error;
 // BPB的spc在第13字节后稳定，提前寄存校验，扇区结束才使用结果。
 // 完成/错误寄存一拍，隔断仲裁器超时到播放器控制的长反馈链。
 // GAP保留三拍，保证解析器收到完成信号并撤回请求后才接受下一事务。
 always @(posedge clk or posedge rst)begin
  if(rst)begin spc_ok<=0;bmp_end<=0;aud_end<=0;bmp_error<=0;aud_error<=0;end
  else begin
   spc_ok<=(spc!=0) && ((spc & (spc-1'b1))==0) && spc<=128;
   bmp_end<=sd_init_done && state[23] && !owner && disk_end && !disk_error && final_count==512 && !cancel_bmp && !bmp_abort;
   aud_end<=sd_init_done && state[23] && owner && disk_end && !disk_error && final_count==512;
   bmp_error<=sd_init_done && !owner && (state[24] ||
    (state[23] && (disk_error || (disk_end && final_count!=512))));
   aud_error<=sd_init_done && owner && (state[24] ||
    (state[23] && (disk_error || (disk_end && final_count!=512))));
  end
 end
 // 授权也是寄存边界，避免FAT状态译码串到原BMP停滞检测与音频复位。
 always @(posedge clk or posedge rst)begin
  if(rst)bmp_grant<=0;
  else bmp_grant<=sd_init_done && mount_done && !owner && !state[18] && !state[25];
 end
 // 元数据的接收使能、字节和索引先寄存，再译码写BPB/目录字段。
 // 末字节在CHECK拍落入字段寄存器，后续状态读取的是完整条目。
 always @(posedge clk or posedge rst)begin
  if(rst)begin meta_valid<=0;meta_boot<=0;meta_dir<=0;meta_index<=0;meta_data<=0;end
  else begin
   meta_valid<=sd_init_done && disk_valid && (state[2] || state[9]);
   meta_boot<=state[2];meta_dir<=state[9];
   meta_index<=byte_count;meta_data<=disk_data;
  end
 end
 // 每个流缓存一个FAT扇区，共1024B；同步读，复位仅清缓存标签。
 always @(posedge clk)begin
  fat_q<=fat_cache[{owner,fat_entry}];
  if(state[14] && disk_valid && byte_count<512 && byte_count[1:0]==3)
   fat_cache[{owner,byte_count[8:2]}]<={disk_data,fat_word[23:0]};
 end
 // synthesis translate_off
 initial if(MAX_BMP<1 || MAX_BMP>4 || ROOT_CLUSTER_LIMIT<1)begin $display("FAILED invalid FAT32 limits");$finish;end
 // synthesis translate_on
 always @(posedge clk or posedge rst)begin
  if(rst)begin
   state<=WAIT_INIT;mount_done<=0;mount_error<=0;mount_error_code<=0;
   bmp_count<=0;wav_found<=0;
   store_bmp<=0;store_wav<=0;store_index<=0;store_cluster<=0;store_size<=0;
   owner<=0;mount_fat<=0;bpb_at_partition<=0;byte_count<=0;
   signature<=0;bytes_per_sector<=0;reserved_count<=0;root_entries<=0;fat16_size<=0;
   total_sectors<=0;fat_sectors<=0;root_cluster<=0;spc<=0;num_fats<=0;ext_flags<=0;fs_version<=0;
   partition_lba<=0;partition_size<=0;selected_lba<=0;partition_found<=0;
   partition_type<=0;partition_candidate<=0;partition_length<=0;physical_addr<=0;spc_shift<=0;
   first_fat<=0;first_data<=0;fat_area<=0;overhead<=0;data_clusters<=0;max_cluster<=0;volume_last<=0;
   data_sectors<=0;total_minus_one<=0;map_minus_two<=0;map_shifted<=0;map_base<=0;
   request_sectors<=0;spc_mask<=0;geometry_bad<=0;root_bad<=0;fat_capacity_bad<=0;
   boot_signature_ok<=0;boot_super_ok<=0;boot_partition_ok<=0;geom_fields_bad<=0;
   cmp_to<=0;cmp_vol<=0;cmp_lo<=0;cmp_hi<=0;
   dir_cluster<=0;dir_sector<=0;dir_hops<=0;dir_ended<=0;
   entry_first<=0;entry_attr<=0;ext0<=0;ext1<=0;ext2<=0;entry_cluster<=0;entry_size<=0;
   cursor_valid<=0;cursor_file<=0;request_rel<=0;request_size<=0;request_file<=0;
   target_index<=0;working_cluster<=0;working_index<=0;
   fat_valid<=0;fat_target<=0;fat_lba<=0;fat_word<=0;fat_entry<=0;next_cluster<=0;
   gap_count<=0;cancel_bmp<=0;cluster_ok<=0;cluster_eoc<=0;cluster_self<=0;stream_bad<=0;fat_rx_bad<=0;
   for(i=0;i<2;i=i+1)begin cursor_cluster[i]<=0;cursor_index[i]<=0;fat_tag[i]<=0;end
  end else if(!sd_init_done)begin
   state<=WAIT_INIT;mount_done<=0;mount_error<=0;mount_error_code<=0;bmp_count<=0;wav_found<=0;
   cursor_valid<=0;fat_valid<=0;owner<=0;bpb_at_partition<=0;partition_found<=0;physical_addr<=0;cancel_bmp<=0;
   partition_lba<=0;partition_size<=0;selected_lba<=0;
   store_bmp<=0;store_wav<=0;
  end else begin
   store_bmp<=0;store_wav<=0;
   // 暂存数据每拍更新，仅store有效脉冲控制描述符表，去掉宽数据CE译码。
   store_cluster<=entry_cluster & 32'h0fffffff;store_size<={meta_data,entry_size[23:0]};store_index<=bmp_count;
   if(bmp_abort)begin cursor_valid[0]<=0;cancel_bmp<=1;end
   if(transferring && disk_valid)begin
    if(byte_count<513)byte_count<=byte_count+1'b1;
    if(state[14])case(byte_count[1:0])
     0:fat_word[7:0]<=disk_data;1:fat_word[15:8]<=disk_data;2:fat_word[23:16]<=disk_data;default:;
    endcase
   end
   if(meta_valid)begin
    if(meta_boot)begin
     case(meta_index)
      11:bytes_per_sector[7:0]<=meta_data;12:bytes_per_sector[15:8]<=meta_data;
      13:spc<=meta_data;14:reserved_count[7:0]<=meta_data;15:reserved_count[15:8]<=meta_data;
      16:num_fats<=meta_data;17:root_entries[7:0]<=meta_data;18:root_entries[15:8]<=meta_data;
      22:fat16_size[7:0]<=meta_data;23:fat16_size[15:8]<=meta_data;
      32:total_sectors[7:0]<=meta_data;33:total_sectors[15:8]<=meta_data;
      34:total_sectors[23:16]<=meta_data;35:total_sectors[31:24]<=meta_data;
      36:fat_sectors[7:0]<=meta_data;37:fat_sectors[15:8]<=meta_data;
      38:fat_sectors[23:16]<=meta_data;39:fat_sectors[31:24]<=meta_data;
      40:ext_flags[7:0]<=meta_data;41:ext_flags[15:8]<=meta_data;
      42:fs_version[7:0]<=meta_data;43:fs_version[15:8]<=meta_data;
      44:root_cluster[7:0]<=meta_data;45:root_cluster[15:8]<=meta_data;
      46:root_cluster[23:16]<=meta_data;47:root_cluster[31:24]<=meta_data;
      510:signature[7:0]<=meta_data;511:signature[15:8]<=meta_data;default:;
     endcase
     if(!bpb_at_partition && meta_index>=446 && meta_index<510)begin
      case((meta_index-446)&15)
       4:partition_type<=meta_data;
       8:partition_candidate[7:0]<=meta_data;9:partition_candidate[15:8]<=meta_data;
       10:partition_candidate[23:16]<=meta_data;11:partition_candidate[31:24]<=meta_data;
       12:partition_length[7:0]<=meta_data;13:partition_length[15:8]<=meta_data;14:partition_length[23:16]<=meta_data;
       15:if(!partition_found && (partition_type==8'h0b || partition_type==8'h0c))begin
        selected_lba<=partition_candidate;partition_size<={meta_data,partition_length[23:0]};partition_found<=1;
       end
       default:;
      endcase
     end
    end
    if(meta_dir)begin
     case(meta_index[4:0])
      0:begin entry_first<=meta_data;if(meta_data==0)dir_ended<=1;end
      8:ext0<=meta_data & 8'hdf;9:ext1<=meta_data & 8'hdf;10:ext2<=meta_data & 8'hdf;
      11:entry_attr<=meta_data;
      20:entry_cluster[23:16]<=meta_data;21:entry_cluster[31:24]<=meta_data;
      26:entry_cluster[7:0]<=meta_data;27:entry_cluster[15:8]<=meta_data;
      28:entry_size[7:0]<=meta_data;29:entry_size[15:8]<=meta_data;30:entry_size[23:16]<=meta_data;
      31:if(!dir_ended && entry_first!=8'he5 && entry_attr[3:0]!=4'hf && (entry_attr&8'h18)==0)begin
       if(ext0=="B" && ext1=="M" && ext2=="P" && bmp_count<MAX_BMP)begin
        store_bmp<=1;bmp_count<=bmp_count+1'b1;
       end
       if(ext0=="W" && ext1=="A" && ext2=="V" && !wav_found)begin
        store_wav<=1;wav_found<=1;
       end
      end
      default:;
     endcase
    end
   end
   case(1'b1) // synthesis parallel_case
    state[0]:begin owner<=0;state<=BOOT_REQ;end
    state[1]:begin byte_count<=0;state<=BOOT_RX;end
    state[2]:if(disk_error || disk_end)begin
     if(disk_error || final_count!=512)begin state<=FAULT;mount_error_code<=2;end else state<=META_DRAIN;
    end
    state[39]:state<=meta_dir?DIR_CHECK:BOOT_CHECK;
    state[3]:begin
     // BPB宽字段比较先寄存，下一拍只用布尔结果更新分区地址。
     boot_signature_ok<=signature==16'haa55;
     boot_super_ok<=bytes_per_sector==512 && spc_ok;
     boot_partition_ok<=!bpb_at_partition && partition_found && selected_lba!=0;
     state<=BOOT_DECIDE;
    end
    state[41]:begin
     if(!boot_signature_ok)begin state<=FAULT;mount_error_code<=1;end
     else if(boot_super_ok)state<=GEOM_FIELDS;
     else if(boot_partition_ok)begin
      bpb_at_partition<=1;partition_lba<=selected_lba;physical_addr<=selected_lba;state<=BOOT_REQ;
     end else begin state<=FAULT;mount_error_code<=1;end
    end
    state[42]:begin
     // 先寄存字段合法性，避免宽比较串到几何寄存器的写使能。
     geom_fields_bad<=!spc_ok || reserved_count==0 || (num_fats!=1 && num_fats!=2) || fat_sectors==0 || fat_sectors[31:24]!=0 ||
        root_entries!=0 || fat16_size!=0 || fs_version!=0 ||
        (ext_flags[7] && ext_flags[3:0]>=num_fats);
     state<=GEOM1;
    end
    state[4]:begin
     if(geom_fields_bad)begin state<=FAULT;mount_error_code<=1;end
     else begin
      case(spc)1:spc_shift<=0;2:spc_shift<=1;4:spc_shift<=2;8:spc_shift<=3;
       16:spc_shift<=4;32:spc_shift<=5;64:spc_shift<=6;default:spc_shift<=7;endcase
      fat_area<=num_fats==2?(fat_sectors<<1):fat_sectors;
      total_minus_one<=total_sectors-1'b1;spc_mask<=spc-1'b1;
      first_fat<=partition_lba+reserved_count;state<=GEOM2;
     end
    end
    state[5]:begin
     overhead<=fat_area+reserved_count;first_data<=first_fat+fat_area;
     volume_last<=partition_lba+total_minus_one;
     if(ext_flags[7] && ext_flags[3:0]==1)first_fat<=first_fat+fat_sectors;
     state<=GEOM3;
    end
    // 减法、可变移位、加一、比较分别寄存，避免100MHz串接进位链。
    state[6]:begin
     data_sectors<=total_sectors-overhead;
     // 依赖GEOM2已寄存的overhead/volume_last，提前完成宽比较。
     cmp_to<=total_sectors<=overhead;cmp_vol<=volume_last<partition_lba;
     state<=GEOM4;
    end
    state[27]:begin data_clusters<=data_sectors>>spc_shift;state<=GEOM5;end
    state[28]:begin
     max_cluster<=data_clusters+1'b1;
     // data_clusters在上一拍GEOM4稳定，此处与加一并行。
     cmp_lo<=data_clusters<65525;cmp_hi<=data_clusters>=32'h0fffffee;
     state<=GEOM6;
    end
    state[29]:begin
     geometry_bad<=cmp_to || cmp_vol || cmp_lo || cmp_hi ||
       (bpb_at_partition && (partition_size<total_sectors || partition_size==0));
     root_bad<=root_cluster<2 || root_cluster>max_cluster;
     fat_capacity_bad<=(fat_sectors<<7)<=max_cluster;
     state<=GEOM7;
    end
    state[30]:begin
     if(geometry_bad || root_bad || fat_capacity_bad)begin
      state<=FAULT;mount_error_code<=1;
     end else begin
      dir_cluster<=root_cluster;dir_sector<=0;dir_hops<=0;state<=DIR_ADDR;
     end
    end
    state[7]:begin map_minus_two<=dir_cluster-2;state<=DIR_SHIFT;end
    state[31]:begin map_shifted<=map_minus_two<<spc_shift;state<=DIR_BASE;end
    state[32]:begin map_base<=first_data+map_shifted;state<=DIR_FINISH;end
    state[33]:begin physical_addr<=map_base+dir_sector;state<=DIR_REQ;end
    state[8]:begin byte_count<=0;dir_ended<=0;state<=DIR_RX;end
    state[9]:if(disk_error || disk_end)begin
     if(disk_error || final_count!=512)begin state<=FAULT;mount_error_code<=2;end else state<=META_DRAIN;
    end
    state[10]:begin
     if(dir_ended)begin mount_done<=1;state<=IDLE;end
     else if(dir_sector<spc_mask)begin dir_sector<=dir_sector+1'b1;state<=DIR_ADDR;end
     else if(dir_hops>=ROOT_CLUSTER_LIMIT-1 || (ROOT_CLUSTER_LIMIT>65525 && dir_hops>=data_clusters))begin state<=FAULT;mount_error_code<=4;end
     else begin fat_target<=dir_cluster;mount_fat<=1;owner<=0;state<=FAT_ADDR;end
    end
    state[11]:begin fat_lba<=first_fat+(fat_target>>7);fat_entry<=fat_target[6:0];state<=FAT_CHECK;end
    state[12]:begin
     if(fat_valid[owner] && fat_tag[owner]==fat_lba)state<=FAT_LOOK;
     else begin physical_addr<=fat_lba;state<=FAT_REQ;end
    end
    state[13]:begin byte_count<=0;fat_valid[owner]<=0;state<=FAT_RX;end
    state[14]:if(disk_error || disk_end)begin
     // 完整扇区校验先寄存，再提交标签，避免字节计数进位链串到缓存CE。
     fat_rx_bad<=disk_error || final_count!=512;state<=FAT_COMMIT;
    end
    state[43]:begin
     if(fat_rx_bad)begin
      if(mount_fat)begin state<=FAULT;mount_error_code<=2;end else state<=STREAM_ERR;
     end else begin fat_valid[owner]<=1;fat_tag[owner]<=fat_lba;state<=FAT_LOOK;end
    end
    state[15]:state<=FAT_GET;
    state[16]:begin next_cluster<=fat_q & 32'h0fffffff;state<=FAT_VALIDATE;end
    state[38]:begin
     cluster_ok<=next_cluster>=2 && next_cluster<=max_cluster && next_cluster<32'h0ffffff0;
     cluster_eoc<=next_cluster>=32'h0ffffff8;cluster_self<=next_cluster==fat_target;
     state<=FAT_EVAL;
    end
    state[17]:begin
     if(mount_fat && cluster_eoc)begin mount_done<=1;state<=IDLE;end
     else if(!cluster_ok || cluster_self)begin
      if(mount_fat)begin state<=FAULT;mount_error_code<=3;end else state<=STREAM_ERR;
     end else if(mount_fat)begin dir_cluster<=next_cluster;dir_sector<=0;dir_hops<=dir_hops+1'b1;state<=DIR_ADDR;end
     else begin working_cluster<=next_cluster;working_index<=working_index+1'b1;state<=STREAM_CHECK;end
    end
    state[18]:begin
     mount_fat<=0;cancel_bmp<=0;
     if(aud_req || bmp_req)begin
      owner<=aud_req;request_file<=bmp_file_idx;
      request_rel<=aud_req?aud_rel_sector:bmp_rel_sector;state<=STREAM_INIT;
     end
    end
    state[19]:begin
     request_size<=owner?wav_size:image_size[request_file[1:0]];
     target_index<=request_rel>>spc_shift;
     state<=STREAM_LIMIT;
    end
    state[34]:begin
     request_sectors<=({1'b0,request_size}+33'd511)>>9;
     // 先寄存目标簇序号，再比较游标，不串接可变移位与宽比较器。
     if(cursor_valid[owner] && (owner || cursor_file==request_file) && cursor_index[owner]<=target_index)begin
      working_cluster<=cursor_cluster[owner];working_index<=cursor_index[owner];
     end else begin working_cluster<=owner?wav_cluster:image_cluster[request_file[1:0]];working_index<=0;end
     state<=STREAM_CHECK;
    end
    state[40]:begin
     stream_bad<=(owner && !wav_found) || (!owner && request_file>=bmp_count) || request_size==0 ||
        {1'b0,request_rel}>=request_sectors || target_index>=data_clusters ||
        working_cluster<2 || working_cluster>max_cluster;
     state<=STREAM_PREP;
    end
    state[20]:begin
     if(stream_bad)state<=STREAM_ERR;
     else if(!owner && (cancel_bmp || bmp_abort))begin gap_count<=2;state<=GAP;end
     else if(working_index==target_index)state<=STREAM_ADDR;
     else begin fat_target<=working_cluster;state<=FAT_ADDR;end
    end
    state[21]:begin
     map_minus_two<=working_cluster-2;
     cursor_cluster[owner]<=working_cluster;cursor_index[owner]<=working_index;cursor_valid[owner]<=1;
     if(!owner)cursor_file<=request_file;
     state<=STREAM_SHIFT;
    end
    state[35]:begin map_shifted<=map_minus_two<<spc_shift;state<=STREAM_BASE;end
    state[36]:begin map_base<=first_data+map_shifted;state<=STREAM_FINISH;end
    state[37]:begin physical_addr<=map_base+(request_rel & {24'd0,spc_mask});state<=STREAM_REQ;end
    state[22]:begin byte_count<=0;state<=STREAM_RX;end
    state[23]:if(disk_error || disk_end)begin
     if(disk_error || final_count!=512)cursor_valid[owner]<=0;
     gap_count<=2;state<=GAP;
    end
    state[24]:begin cursor_valid[owner]<=0;gap_count<=2;state<=GAP;end
    state[25]:if(gap_count==0)state<=IDLE;else gap_count<=gap_count-1'b1;
    state[26]:begin mount_error<=1;mount_done<=0;end
    default:state<=WAIT_INIT;
   endcase
  end
 end
endmodule
