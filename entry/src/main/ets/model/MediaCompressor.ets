import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export class MediaCompressor {
  static readonly MB = 1024 * 1024;

  static qualityValue(level: number): number {
    if (level == 1) return 90;
    if (level == 2) return 75;
    return 60;
  }

  static async process(context: common.UIAbilityContext, path: string, mime: string,
    maxBytes: number, level: number): Promise<string> {
    const stat = fileIo.statSync(path);
    const isGif = mime == 'image/gif';
    if (level == 0) {
      if (stat.size <= maxBytes) return path;
      throw new Error(`文件 ${(stat.size / MediaCompressor.MB).toFixed(1)}MB 超过上限 ${(maxBytes / MediaCompressor.MB).toFixed(0)}MB，请选择压缩质量`);
    }

    const source = image.createImageSource(path);
    const packer = image.createImagePacker();
    try {
      if (isGif) {
        try {
          const option: image.PackingOption = { format: 'image/gif', quality: 100 };
          const data = await packer.packing(source, option);
          if (data.byteLength > maxBytes) throw new Error('GIF 压缩后仍超过大小上限，请先裁剪尺寸');
          return MediaCompressor.write(context, data, 'gif');
        } catch (e) {
          if (stat.size <= maxBytes) return path;
          throw e as Error;
        }
      }

      let pixel = await source.createPixelMap();
      let quality = MediaCompressor.qualityValue(level);
      let data = await packer.packing(pixel, { format: 'image/jpeg', quality: quality });
      while (data.byteLength > maxBytes && quality > 30) {
        quality -= 10;
        data = await packer.packing(pixel, { format: 'image/jpeg', quality: quality });
      }
      let scaleCount = 0;
      while (data.byteLength > maxBytes && scaleCount < 6) {
        await pixel.scale(0.8, 0.8);
        data = await packer.packing(pixel, { format: 'image/jpeg', quality: 75 });
        scaleCount++;
      }
      pixel.release();
      return MediaCompressor.write(context, data, 'jpg');
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
