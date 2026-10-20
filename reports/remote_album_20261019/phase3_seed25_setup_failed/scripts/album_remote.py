"""Explicitly invoked PC client for the FPGA's 115200 8N1 UART.

Requires pyserial only when opening a port. Does not touch hardware on import.
"""
import argparse
import datetime as dt
import time

BEIJING=dt.timezone(dt.timedelta(hours=8))

def time_packet(now=None):
    now=now or dt.datetime.now(BEIJING)
    return b'T'+now.astimezone(BEIJING).strftime('%H%M%S').encode('ascii')

def exchange(port,packet):
    port.write(packet)
    port.flush()
    reply=port.read(1)
    if reply!=b'K':
        raise RuntimeError(f'{packet!r}: expected K, received {reply!r}')
    return reply

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port',required=True,help='Windows serial port, e.g. COM3')
    parser.add_argument('--command',choices=['n','p','b'],help='next / previous / toggle auto-play')
    parser.add_argument('--time',help='HHMMSS in Beijing time; calendar checked by FPGA')
    parser.add_argument('--sync',action='store_true',help='send Beijing wall time every second until Ctrl+C')
    args=parser.parse_args()
    if not (args.command or args.time or args.sync):parser.error('choose --command, --time or --sync')
    if args.time:
        try:dt.datetime.strptime(args.time,'%H%M%S')
        except ValueError:parser.error('--time must be valid HHMMSS')
        if len(args.time)!=6 or not args.time.isascii() or not args.time.isdigit():parser.error('--time must have six digits')
    import serial
    with serial.Serial(args.port,115200,timeout=1,write_timeout=1) as port:
        if args.command:print(exchange(port,args.command.encode()))
        if args.time:print(exchange(port,b'T'+args.time.encode()))
        if args.sync:
            try:
                while True:
                    packet=time_packet();print(packet.decode(),exchange(port,packet).decode())
                    time.sleep(1)
            except KeyboardInterrupt:pass

if __name__=='__main__':main()
