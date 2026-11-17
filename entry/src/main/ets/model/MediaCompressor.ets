import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { I18n } from './I18n';
import { MediaQuality } from './MediaQuality';

export class MediaCompressor {
  // Product convention: 1 MB = 1,000,000 bytes.
  static readonly MB = 1000 * 1000;

  private static nextLowerQuality(quality: number): number {
    if (quality > 90) return 90;
    if (quality > 75) return 75;
    if (quality > 60) return 60;
    return 60;
  }

  static async process(context: common.UIAbilityContext, path: string, mime: string,
    maxBytes: number, qualityPosition: number): Promise<string> {
    const stat = fileIo.statSync(path);
    const isGif = mime == 'image/gif';
    const original = MediaQuality.isOriginal(qualityPosition);

    // 原画默认保留原始文件；只有超过官方上限时才压缩。
    if (original && stat.size <= maxBytes) return path;

    const source = image.createImageSource(path);
    const packer = image.createImagePacker();
    try {
      if (isGif) {
        let q = original ? 90 : MediaQuality.valueAt(qualityPosition);
        let data: ArrayBuffer;
        try {
          data = await packer.packing(source, { format: 'image/gif', quality: q });
        } catch (e) {
          if (original && stat.size <= maxBytes) return path;
          throw e as Error;
        }
        while (data.byteLength > maxBytes && q > 60) {
          q = MediaCompressor.nextLowerQuality(q);
          data = await packer.packing(source, { format: 'image/gif', quality: q });
        }
        if (data.byteLength > maxBytes) {
          throw new Error(I18n.t('GIF 压缩到省流后仍超过大小上限，请先裁剪尺寸'));
        }
        return MediaCompressor.write(context, data, 'gif');
      }

      let pixel = await source.createPixelMap();
      try {
        let q = original ? 90 : MediaQuality.valueAt(qualityPosition);
        let data = await packer.packing(pixel, { format: 'image/jpeg', quality: q });
        while (data.byteLength > maxBytes && q > 60) {
          q = MediaCompressor.nextLowerQuality(q);
          data = await packer.packing(pixel, { format: 'image/jpeg', quality: q });
        }
        if (data.byteLength > maxBytes) {
          throw new Error(I18n.t('图片压缩到省流后仍超过大小上限，请裁剪尺寸'));
        }
        return MediaCompressor.write(context, data, 'jpg');
      } finally {
        pixel.release();
      }
    } finally {
      packer.release();
      source.release();
    }
  }

  private static write(context: common.UIAbilityContext, data: ArrayBuffer, ext: string): string {
    const dest = `${context.cacheDir}/compressed_${Date.now()}.${ext}`;
    const file = fileIo.openSync(dest, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, data);
    } finally {
      fileIo.closeSync(file);
    }
    return dest;
  }
}
