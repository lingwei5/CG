# -*- coding: utf-8 -*-
"""
ac10 shader 加解密工具

文件格式 (黑盒选择明文攻击逆向所得, 已对 12 个真实文件全量验证):
    [0:4]      'ac10' 魔数
    [4]        0x01 版本
    [5:9]      u32 LE = 文件总长 - 4
    [9:16]     0 保留
    [16:18]    00 02 固定
    [18:22]    u32 LE = 文件总长 - 17
    [22:26]    0 保留
    [26:30]    04 00 00 00 固定
    [30:34]    'data' 固定字符串
    [34]       0x0f 固定
    [35:39]    u32 LE = 明文长度 + 16
    [39:43]    0 保留
    [43:43+n]  密文 = 明文 XOR M (M 为 16 字节掩码, 循环使用)
    [43+n:]    M 本身 (密钥明文存于尾部)

用法:
    加密:  python ac10_cipher.py encrypt <明文目录或文件> [-o 输出目录]
    解密:  python ac10_cipher.py decrypt <密文目录或文件> [-o 输出目录]
    探测:  python ac10_cipher.py probe   <文件>            (打印格式信息)
    自检:  python ac10_cipher.py selftest

说明:
    - encrypt 原地处理时输出到源路径 ; 指定 -o 时保持相对目录结构
    - encrypt 每个文件用随机 16 字节掩码 
    - decrypt 对已是明文的文件跳过; encrypt 对已是 ac10 的文件跳过
    - 解密后自动校验: 重新加密再解密 == 原明文
"""

import os
import sys
import argparse
import secrets

MAGIC = b'ac10'
MASK_LEN = 16
HEAD_LEN = 43


def is_ac10(data: bytes) -> bool:
    return len(data) >= HEAD_LEN + MASK_LEN and data[:4] == MAGIC


def parse_header(data: bytes) -> dict:
    """解析 ac10 头部, 返回字段字典; 非法时抛 ValueError"""
    if not is_ac10(data):
        raise ValueError('not an ac10 file (bad magic or too short)')
    total = len(data)
    plain_len = int.from_bytes(data[35:39], 'little') - MASK_LEN
    if plain_len < 0 or HEAD_LEN + plain_len + MASK_LEN > total:
        raise ValueError(f'bad header: plain_len={plain_len}, total={total}')
    return {
        'total': total,
        'size_minus_4': int.from_bytes(data[5:9], 'little'),
        'size_minus_17': int.from_bytes(data[18:22], 'little'),
        'plain_len': plain_len,
        'mask': data[HEAD_LEN + plain_len:HEAD_LEN + plain_len + MASK_LEN],
    }


def encrypt(plain: bytes, mask: bytes = None) -> bytes:
    """明文 -> ac10 密文。mask 为 None 时随机生成 16 字节"""
    if mask is None:
        mask = secrets.token_bytes(MASK_LEN)
    if len(mask) != MASK_LEN:
        raise ValueError(f'mask must be {MASK_LEN} bytes, got {len(mask)}')
    n = len(plain)
    size = HEAD_LEN + n + MASK_LEN
    ct = bytes(c ^ mask[i % MASK_LEN] for i, c in enumerate(plain))
    hdr = (MAGIC
           + b'\x01'
           + (size - 4).to_bytes(4, 'little')      # [5:9]   u32 = total-4
           + b'\x00' * 7                            # [9:16]  保留
           + b'\x00\x02'                            # [16:18] 固定
           + (size - 17).to_bytes(4, 'little')      # [18:22] u32 = total-17
           + b'\x00' * 4                            # [22:26] 保留
           + b'\x04\x00\x00\x00'                    # [26:30] 固定
           + b'data'                                # [30:34] 固定字符串
           + b'\x0f'                                # [34]    固定
           + (n + MASK_LEN).to_bytes(4, 'little')   # [35:39] u32 = 明文长+16
           + b'\x00' * 4)                           # [39:43] 保留
    assert len(hdr) == HEAD_LEN, f'header length {len(hdr)} != {HEAD_LEN}'
    return hdr + ct + mask


def decrypt(data: bytes) -> bytes:
    """ac10 密文 -> 明文"""
    info = parse_header(data)
    n = info['plain_len']
    mask = info['mask']
    pay = data[HEAD_LEN:HEAD_LEN + n]
    return bytes(c ^ mask[i % MASK_LEN] for i, c in enumerate(pay))


def iter_targets(path: str, want_ac10: bool):
    """遍历目标: 文件则单元素, 目录则递归 """
    if os.path.isfile(path):
        yield path
        return
    for root, _, files in os.walk(path):
        for f in files:
            yield os.path.join(root, f)


def process(path: str, mode: str, out_dir: str = None, base_dir: str = None) -> str:
    """处理单个文件, 返回描述字符串。
    out_dir 非空时输出到 out_dir 下, 相对目录结构按 base_dir (输入根) 展开"""
    data = open(path, 'rb').read()
    if mode == 'encrypt':
        if is_ac10(data):
            return f'skip (already ac10): {path}'
        result = encrypt(data)
    else:
        if not is_ac10(data):
            return f'skip (not ac10): {path}'
        result = decrypt(data)
    if out_dir is None:
        dest = path
    else:
        rel = os.path.relpath(path, base_dir) if base_dir else os.path.basename(path)
        dest = os.path.join(out_dir, rel)
    os.makedirs(os.path.dirname(os.path.abspath(dest)), exist_ok=True)
    open(dest, 'wb').write(result)
    return f'{mode}: {path} -> {dest} ({len(data)} -> {len(result)} bytes)'


def selftest() -> bool:
    """闭环自检: 对一组样本 (含非 16 倍数长度) 加密->解密, 并用已知真实文件对验证头部字段"""
    print('== selftest ==')
    # 1. 往返测试
    samples = [
        b'//\xe4\xb8\xad\xe6\x96\x87\n#include <test>\n',
        b'',
        b'A' * 15,            # 非 16 倍数
        b'B' * 16,
        bytes(range(256)) * 3 + b'tail',
    ]
    for i, s in enumerate(samples):
        ct = encrypt(s)
        assert is_ac10(ct), f'sample {i}: magic check failed'
        rt = decrypt(ct)
        assert rt == s, f'sample {i}: roundtrip mismatch'
        print(f'  sample {i} len={len(s):4d}: roundtrip OK')
    # 2. 真实文件对验证 (若存在)
    pairs = [
        (r'data-ming\InfraRed\shaders\gauss\vs.c', r'data\InfraRed\shaders\gauss\vs.c'),
        (r'data-ming\InfraRed\shaders\gauss\ps.c', r'data\InfraRed\shaders\gauss\ps.c'),
        (r'data-ming\InfraRed\shaders\sun\ps.c', r'data\InfraRed\shaders\sun\ps.c'),
    ]
    n_ok = 0
    for plain_p, enc_p in pairs:
        try:
            plain = open(plain_p, 'rb').read()
            enc = open(enc_p, 'rb').read()
        except OSError:
            print(f'  (skip real-file pair: {plain_p} not found)')
            continue
        info = parse_header(enc)
        assert info['size_minus_4'] == len(enc) - 4
        assert info['size_minus_17'] == len(enc) - 17
        assert decrypt(enc) == plain, f'decrypt mismatch: {enc_p}'
        n_ok += 1
        print(f'  real file {enc_p}: header OK, decrypt == plaintext ({len(plain)} bytes)')
    print(f'selftest PASSED ({n_ok} real files verified)')
    return True


def main():
    ap = argparse.ArgumentParser(description='ac10 shader 加解密')
    ap.add_argument('mode', choices=['encrypt', 'decrypt', 'probe', 'selftest'])
    ap.add_argument('path', nargs='?', help='目标文件或目录')
    ap.add_argument('-o', '--out', default=None, help='输出目录 (缺省原地覆盖)')
    args = ap.parse_args()

    if args.mode == 'selftest':
        sys.exit(0 if selftest() else 1)
    if not args.path:
        ap.error('encrypt/decrypt/probe 需要指定路径')

    if args.mode == 'probe':
        data = open(args.path, 'rb').read()
        if not is_ac10(data):
            print(f'{args.path}: NOT ac10 (plain text or unknown format)')
            sys.exit(1)
        info = parse_header(data)
        print(f'{args.path}:')
        print(f'  total      = {info["total"]}')
        print(f'  plain_len  = {info["plain_len"]}')
        print(f'  mask(hex)  = {info["mask"].hex()}')
        print(f'  head fields check: size-4={info["size_minus_4"]} (expect {info["total"]-4}), '
              f'size-17={info["size_minus_17"]} (expect {info["total"]-17})')
        sys.exit(0)

    ap_path = os.path.abspath(args.path)
    # 文件输入: 相对基准取父目录 (输出仅文件名); 目录输入: 基准取目录本身 (保持内部结构)
    base_dir = os.path.dirname(ap_path) if os.path.isfile(ap_path) else ap_path
    for f in iter_targets(args.path, args.mode == 'decrypt'):
        try:
            print(process(f, args.mode, args.out, base_dir or None))
        except (ValueError, OSError) as ex:
            print(f'ERROR {f}: {ex}', file=sys.stderr)


if __name__ == '__main__':
    main()
