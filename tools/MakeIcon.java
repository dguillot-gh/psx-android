// Turns a game's box art into its Android app icon. Hand-written; runs with the JDK alone:
//   java tools\MakeIcon.java <boxart.png> <out ic_launcher_art.png>
// Prints the cover's average colour (#RRGGBB) for the icon background.
// A North American PS1 cover has a black "PlayStation" spine down its left edge: when the left
// strip is mostly dark it is cropped off, so the icon shows the artwork and the title. The rest
// is centre-cropped to a square and scaled to 432x432 (108dp at xxxhdpi, Android's icon size).
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.File;
import javax.imageio.ImageIO;

public class MakeIcon {
    public static void main(String[] args) throws Exception {
        BufferedImage src = ImageIO.read(new File(args[0]));
        int w = src.getWidth(), h = src.getHeight();

        // Spine: the left 10% is dark (average luminance under 70 of 255) on NTSC-U covers.
        int x0 = 0;
        long lum = 0, n = 0;
        for (int y = 0; y < h; y += 2)
            for (int x = 0; x < w / 10; x += 2) {
                int p = src.getRGB(x, y);
                lum += (((p >> 16) & 255) * 299 + ((p >> 8) & 255) * 587 + (p & 255) * 114) / 1000;
                n++;
            }
        if (n > 0 && lum / n < 70) x0 = Math.round(w * 0.156f);

        int cw = w - x0, side = Math.min(cw, h);
        int cx = x0 + (cw - side) / 2, cy = (h - side) / 2;
        BufferedImage crop = src.getSubimage(cx, cy, side, side);

        // Scale down in halving steps (sharper than one big bilinear step), then to 432.
        BufferedImage img = crop;
        int size = side;
        while (size / 2 >= 432) { img = scale(img, size / 2); size /= 2; }
        img = scale(img, 432);
        ImageIO.write(img, "png", new File(args[1]));

        long r = 0, g = 0, b = 0, m = 0;
        for (int y = 0; y < 432; y += 3)
            for (int x = 0; x < 432; x += 3) {
                int p = img.getRGB(x, y);
                r += (p >> 16) & 255; g += (p >> 8) & 255; b += p & 255; m++;
            }
        System.out.printf("#%02X%02X%02X%n", r / m, g / m, b / m);
    }

    static BufferedImage scale(BufferedImage in, int size) {
        BufferedImage out = new BufferedImage(size, size, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = out.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BICUBIC);
        g.setRenderingHint(RenderingHints.KEY_RENDERING, RenderingHints.VALUE_RENDER_QUALITY);
        g.drawImage(in, 0, 0, size, size, null);
        g.dispose();
        return out;
    }
}
