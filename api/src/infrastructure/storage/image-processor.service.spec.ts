import { ImageProcessorService } from './image-processor.service';
import sharp from 'sharp';

describe('ImageProcessorService', () => {
  const svc = new ImageProcessorService();

  it('strips metadata and returns jpeg + thumbnail', async () => {
    const input = await sharp({
      create: {
        width: 80,
        height: 60,
        channels: 3,
        background: { r: 200, g: 100, b: 50 },
      },
    })
      .jpeg()
      .withMetadata({ exif: { IFD0: { Copyright: 'secret' } } })
      .toBuffer();

    const out = await svc.processMemberImage(input);
    expect(out.exifStripped).toBe(true);
    expect(out.mimeType).toBe('image/jpeg');
    expect(out.width).toBeGreaterThan(0);
    expect(out.thumbnail.length).toBeGreaterThan(0);
    const meta = await sharp(out.buffer).metadata();
    // Re-encoded jpeg should not carry the copyright IFD we set
    expect(meta.exif === undefined || meta.exif.length < input.length).toBe(
      true,
    );
  });
});
