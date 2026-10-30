"""Builds macos/AppIcon.icns from the title-screen bitmap embedded in game/game.swf.

Usage: python3 tools/make_icon.py game/game.swf macos/AppIcon.icns
Requires Pillow. Only needed when the icon has to be regenerated.
"""
import io
import struct
import sys
import zlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

TITLE_BITMAP_ID = 621  # DefineBits (JPEG) character holding the 550x400 title screen
CROP_BOX = (176, 82, 536, 400)  # drill pod region of the title screen, below the logo text


def read_title_bitmap(swf_path):
    data = open(swf_path, 'rb').read()
    if data[:3] == b'CWS':
        body = zlib.decompress(data[8:])
    elif data[:3] == b'FWS':
        body = data[8:]
    else:
        raise SystemExit('unsupported SWF signature: %r' % data[:3])
    nbits = body[0] >> 3
    pos = (5 + 4 * nbits + 7) // 8 + 4
    jpeg_tables = b''
    while pos < len(body):
        header = struct.unpack('<H', body[pos:pos + 2])[0]
        pos += 2
        code, length = header >> 6, header & 0x3F
        if length == 0x3F:
            length = struct.unpack('<I', body[pos:pos + 4])[0]
            pos += 4
        tag = body[pos:pos + length]
        pos += length
        if code == 0:
            break
        if code == 8:  # JPEGTables
            jpeg_tables = tag
        elif code == 6 and struct.unpack('<H', tag[:2])[0] == TITLE_BITMAP_ID:  # DefineBits
            tables = jpeg_tables[:-2] if jpeg_tables.endswith(b'\xff\xd9') else jpeg_tables
            image_data = tag[2:]
            if image_data.startswith(b'\xff\xd8'):
                image_data = image_data[2:]
            return Image.open(io.BytesIO(tables + image_data)).convert('RGB')
    raise SystemExit('title bitmap %d not found' % TITLE_BITMAP_ID)


def build_icon(title):
    size, inset, radius = 1024, 100, 185
    tile_size = size - 2 * inset
    pod = title.crop(CROP_BOX)
    pod = pod.resize((tile_size, round(pod.height * tile_size / pod.width)), Image.LANCZOS)

    # The crop is wider than tall: fill the square tile with a blurred backdrop
    # and fade the top and bottom edges of the pod image into it.
    art = title.crop(CROP_BOX).resize((tile_size, tile_size), Image.LANCZOS)
    art = art.filter(ImageFilter.GaussianBlur(24)).point(lambda v: v * 0.7)
    fade = Image.new('L', pod.size, 255)
    draw = ImageDraw.Draw(fade)
    feather = 48
    for y in range(feather):
        value = round(255 * y / feather)
        draw.line((0, y, pod.width, y), fill=value)
        draw.line((0, pod.height - 1 - y, pod.width, pod.height - 1 - y), fill=value)
    art.paste(pod, (0, (tile_size - pod.height) // 2), fade)

    mask = Image.new('L', art.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, art.width - 1, art.height - 1), radius, fill=255)

    shadow = Image.new('L', (size, size), 0)
    shadow.paste(mask, (inset, inset + 12))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18)).point(lambda v: v * 0.5)

    icon = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    icon.putalpha(shadow)
    tile = art.convert('RGBA')
    tile.putalpha(mask)
    icon.alpha_composite(tile, (inset, inset))

    border = Image.new('L', art.size, 0)
    ImageDraw.Draw(border).rounded_rectangle((0, 0, art.width - 1, art.height - 1), radius, outline=255, width=6)
    edge = Image.new('RGBA', art.size, (0, 0, 0, 90))
    edge.putalpha(ImageChops.multiply(border, Image.new('L', art.size, 90)))
    icon.alpha_composite(edge, (inset, inset))
    return icon


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    icon = build_icon(read_title_bitmap(sys.argv[1]))
    icon.save(sys.argv[2], format='ICNS')


if __name__ == '__main__':
    main()
