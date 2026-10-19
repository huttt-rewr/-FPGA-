from pathlib import Path
r=Path('E:/fpga');h=r/'reports/timing_close_20261018'
s=(h/'initial/sd_fat32.v').read_text(encoding='utf-8')
# Preserve each original guard's sampled value; move only the final OR to
# the following PREP decision, without changing any state/handshake clock.
assert 'reg cluster_ok,cluster_eoc,cluster_self,stream_bad,fat_rx_bad;' in s;s=s.replace('reg cluster_ok,cluster_eoc,cluster_self,stream_bad,fat_rx_bad;', '''reg cluster_ok,cluster_eoc,cluster_self,fat_rx_bad;
 reg [5:0] stream_bad_parts;
 wire stream_bad=|stream_bad_parts;''')
assert 'stream_bad<=0;' in s;s=s.replace('stream_bad<=0;','stream_bad_parts<=0;')
a='''     stream_bad<=(owner && !wav_found) || (!owner && request_file>=bmp_count) || request_size==0 ||
        {1'b0,request_rel}>=request_sectors || target_index>=data_clusters ||
        working_cluster<2 || working_cluster>max_cluster;'''
b='''     // Sample independent guards in parallel. Their final OR is consumed
     // by STREAM_PREP on the same next clock as the original stream_bad FF.
     // No request cycle or boundary arithmetic is changed.
     stream_bad_parts<={((owner && !wav_found) || (!owner && request_file>=bmp_count)),
       (request_size==0),({1'b0,request_rel}>=request_sectors),
       (target_index>=data_clusters),(working_cluster<2),(working_cluster>max_cluster)};'''
assert a in s;s=s.replace(a,b)
(h/'fat_guard_partition_candidate.v').write_text(s,encoding='utf-8')
print('Prepared exact register/OR repartition candidate outside active build inputs')
