import plistlib
import re
import sys

START_INDEX = 1616
SLICE_LENGTH = 200

def error(msg: str) -> None:
    print(f"error: {msg}")
    sys.exit(1)

def main(mode: str, plist_path: str) -> None:
    with open(plist_path, "rb") as f:
        plist_data = plistlib.load(f)

    cache_data = plist_data.get("CacheData")
    if not isinstance(cache_data, bytes):
        error("CacheData is not bytes")

    hex_string = cache_data.hex().upper()
    if len(hex_string) <= START_INDEX:
        error("hex string too short")

    sliced_hex = hex_string[START_INDEX : START_INDEX + SLICE_LENGTH]

    pattern = re.compile(r"0+(?:5555)*([0-9A-F]{4})")
    absolute_offset = None
    pattern_value = None

    for match in pattern.finditer(sliced_hex):
        value = match.group(1)
        if sum(c != "0" for c in value) >= 3:
            slice_offset = match.start(1)
            absolute_offset = START_INDEX + slice_offset
            pattern_value = value
            break

    if absolute_offset is None or pattern_value is None:
        error("pattern not found")

    right_offset = absolute_offset + 13
    if right_offset >= len(hex_string):
        error("right offset out of range")

    right_value = hex_string[right_offset]
    if right_value not in ("1", "3"):
        error("right value must be 1 or 3")

    if not (
        right_offset - 1 >= 0
        and hex_string[right_offset - 1] == "0"
        and right_offset + 1 < len(hex_string)
        and hex_string[right_offset + 1] == "0"
    ):
        error("right neighbors must be 0")

    # Dynamic backward search for iOS 26.4 compatibility
    left_offset = None
    i = absolute_offset - 1
    while i > 0:
        if hex_string[i] == '0':
            i -= 1
        elif i >= 3 and hex_string[i - 3 : i + 1] == '5555':
            i -= 4
        elif hex_string[i] in ('1', '3'):
            # Check neighbors
            if hex_string[i - 1] == '0' and hex_string[i + 1] == '0':
                left_offset = i
                left_value = hex_string[left_offset]
                break
            else:
                error("dynamic search found 1/3 but neighbors are not 0")
        else:
            error(f"non-zero and non-5555 value found during backward search: {hex_string[i]} at {i}")

    if left_offset is None:
        error("left offset not found in dynamic search")

    print(f"pattern_value: {pattern_value}")
    print(f"left_before: {left_value}")
    print(f"right_before: {right_value}")

    new_left = "3" if mode == "enable" else "1"
    hex_list = list(hex_string)
    hex_list[left_offset] = new_left
    new_hex_string = "".join(hex_list)
    plist_data["CacheData"] = bytes.fromhex(new_hex_string)

    # 元の plist を上書き保存する
    with open(plist_path, "wb") as out_f:
        plistlib.dump(plist_data, out_f, fmt=plistlib.FMT_BINARY)

    # 上書き後の内容を念のため検証
    with open(plist_path, "rb") as f:
        patched_plist = plistlib.load(f)
    patched_cache = patched_plist.get("CacheData")
    if not isinstance(patched_cache, bytes):
        error("patched CacheData is not bytes")
    patched_hex = patched_cache.hex().upper()
    if left_offset >= len(patched_hex):
        error("patched hex string too short")
    patched_left_value = patched_hex[left_offset]

    print(f"left_after: {patched_left_value}")
    print(f"output_plist: {plist_path}")
    
if __name__ == "__main__":
    if (
        len(sys.argv) < 3
        or sys.argv[1] not in ("enable", "disable")
    ):
        error("usage: python trollpad_patcher.py [enable|disable] /path/to/Off.plist")
    mode_arg = sys.argv[1]
    plist_path_arg = sys.argv[2]
    main(mode_arg, plist_path_arg)
