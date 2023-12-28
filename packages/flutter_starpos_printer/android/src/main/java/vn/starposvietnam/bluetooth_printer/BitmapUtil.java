package vn.starposvietnam.bluetooth_printer;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Rect;
import android.graphics.Typeface;
import android.text.Layout;
import android.text.StaticLayout;
import android.text.TextPaint;
import android.util.Log;

import com.google.zxing.BarcodeFormat;
import com.google.zxing.EncodeHintType;
import com.google.zxing.MultiFormatWriter;
import com.google.zxing.WriterException;
import com.google.zxing.common.BitMatrix;
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel;

import java.util.HashMap;
import java.util.Map;

/**
 * Created by Administrator on 2017/5/3.
 */

public class BitmapUtil {

    /**
     * @param content
     * @param format
     * @param width
     * @param height
     * @return
     */
    public static Bitmap generateQRBitmap(String content, int format, int width, int height) {
        if (content == null || content.equals(""))
            return null;
        BarcodeFormat barcodeFormat;
        switch (format) {
            case 0:
                barcodeFormat = BarcodeFormat.UPC_A;
                break;
            case 1:
                barcodeFormat = BarcodeFormat.UPC_E;
                break;
            case 2:
                barcodeFormat = BarcodeFormat.EAN_13;
                break;
            case 3:
                barcodeFormat = BarcodeFormat.EAN_8;
                break;
            case 4:
                barcodeFormat = BarcodeFormat.CODE_39;
                break;
            case 5:
                barcodeFormat = BarcodeFormat.ITF;
                break;
            case 6:
                barcodeFormat = BarcodeFormat.CODABAR;
                break;
            case 7:
                barcodeFormat = BarcodeFormat.CODE_93;
                break;
            case 8:
                barcodeFormat = BarcodeFormat.CODE_128;
                break;
            case 9:
                barcodeFormat = BarcodeFormat.QR_CODE;
                break;
            default:
                barcodeFormat = BarcodeFormat.QR_CODE;
                height = width;
                break;
        }
        MultiFormatWriter qrCodeWriter = new MultiFormatWriter();
        Map<EncodeHintType, Object> hints = new HashMap<>();
        hints.put(EncodeHintType.CHARACTER_SET, "GBK");
        hints.put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.H);
        try {
            BitMatrix encode = qrCodeWriter.encode(content, barcodeFormat, width, height, hints);
            int[] pixels = new int[width * height];
            for (int i = 0; i < height; i++) {
                for (int j = 0; j < width; j++) {
                    if (encode.get(j, i)) {
                        pixels[i * width + j] = 0x00000000;
                    } else {
                        pixels[i * width + j] = 0xffffffff;
                    }
                }
            }
            return Bitmap.createBitmap(pixels, 0, width, width, height, Bitmap.Config.RGB_565);
        } catch (WriterException e) {
            e.printStackTrace();
        } catch (IllegalArgumentException e) {
            e.printStackTrace();
        }
        return null;
    }

    public static Bitmap textToBitmap(String text, int textSize, int padding) {
        Paint paint = new Paint();
        paint.setTextSize(textSize); // Set the text size as needed
        paint.setColor(Color.BLACK); // Set the text color

        Rect bounds = new Rect();
        paint.getTextBounds(text, 0, text.length(), bounds);

        int width = bounds.width() + 2 * padding;
        int height = bounds.height() + 2 * padding;

        Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);

        // Draw a white background
        canvas.drawColor(Color.WHITE);

        // Draw the text in the center with padding
        float x = padding;
        float y = height - padding - paint.descent();
        canvas.drawText(text, x, y, paint);

        return bitmap;
    }

    /**
     *
     * Typeface.SANS_SERIF : Typeface.MONOSPACE
     */
    public static Bitmap textToBitmap(String str, int dotPerRow, int textSize, int padding, Typeface typeface) {
        TextPaint textPaint = new TextPaint();
        textPaint.setStyle(Paint.Style.FILL);
        textPaint.setColor(Color.BLACK);
        textPaint.setTextSize((float) textSize);
        textPaint.setTypeface(Typeface.create(typeface, Typeface.NORMAL));
        StaticLayout staticLayout = new StaticLayout(str, textPaint, dotPerRow, Layout.Alignment.ALIGN_NORMAL, 1.0f,
                0.0f, false);
        Bitmap createBitmap = Bitmap.createBitmap(dotPerRow, staticLayout.getHeight(), Bitmap.Config.RGB_565);
        Canvas canvas = new Canvas(createBitmap);
        Paint paint = new Paint();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(-1);
        canvas.drawPaint(paint);
        canvas.save();
        canvas.translate(0.0f, 0.0f);
        staticLayout.draw(canvas);
        canvas.restore();
        return createBitmap;
    }

    /**
     *
     * Typeface.SANS_SERIF : Typeface.MONOSPACE
     */
    public static Bitmap textToBitmap(String str, int dotPerRow, int textSize, Typeface typeface, boolean bold,
            Layout.Alignment align) {
        TextPaint textPaint = new TextPaint();
        textPaint.setStyle(Paint.Style.FILL);
        textPaint.setColor(Color.BLACK);
        textPaint.setTextSize((float) textSize);
        textPaint.setTypeface(Typeface.create(typeface, bold ? Typeface.BOLD : Typeface.NORMAL));
        StaticLayout staticLayout = new StaticLayout(str, textPaint, dotPerRow, align, 1.0f, 0.0f, false);
        Bitmap createBitmap = Bitmap.createBitmap(dotPerRow, staticLayout.getHeight(), Bitmap.Config.RGB_565);
        Canvas canvas = new Canvas(createBitmap);
        Paint paint = new Paint();
        paint.setStyle(Paint.Style.FILL);
        paint.setColor(-1);
        canvas.drawPaint(paint);
        canvas.save();
        canvas.translate(0.0f, 0.0f);
        staticLayout.draw(canvas);
        canvas.restore();
        return createBitmap;
    }

    public static Bitmap mergeBitmaps(Bitmap bitmap1, Bitmap bitmap2) {
        int width = bitmap1.getWidth() + bitmap2.getWidth();
        int height = Math.max(bitmap1.getHeight(), bitmap2.getHeight());

        // Create a new bitmap with a white background
        Bitmap mergedBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(mergedBitmap);

        // Draw a white background
        canvas.drawColor(Color.WHITE);

        // Draw the first bitmap at the left side
        canvas.drawBitmap(bitmap1, 0, 0, null);

        // Draw the second bitmap next to the first one
        canvas.drawBitmap(bitmap2, bitmap1.getWidth(), 0, null);

        return mergedBitmap;
    }

    public static Bitmap mergeBitmapsVertical(Bitmap bitmap1, Bitmap bitmap2) {
        int width = Math.max(bitmap1.getWidth(), bitmap2.getWidth());
        int height = bitmap1.getHeight() + bitmap2.getHeight();

        Bitmap mergedBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(mergedBitmap);

        // Draw a white background
        canvas.drawColor(Color.WHITE);

        // Draw the first bitmap at the top
        canvas.drawBitmap(bitmap1, (width - bitmap1.getWidth()) / 2, 0, null);

        // Draw the second bitmap below the first one
        canvas.drawBitmap(bitmap2, 20, bitmap1.getHeight(), null);

        return mergedBitmap;
    }

    /**
     * Scaled image width is an integer multiple of 8 and can be ignored
     */
    public static Bitmap scaleImage(Bitmap bitmap1) {
        int width = bitmap1.getWidth();
        int height = bitmap1.getHeight();
        int newWidth = (width / 8 + 1) * 8;
        float scaleWidth = ((float) newWidth) / width;
        Matrix matrix = new Matrix();
        matrix.postScale(scaleWidth, 1);
        return Bitmap.createBitmap(bitmap1, 0, 0, width, height, matrix, true);
    }

    public static Bitmap resizeImage(Bitmap bitmap, int newWidth, boolean scale) {
        int width = bitmap.getWidth();
        int height = bitmap.getHeight();

        Log.i("HTML", "--> width = " + width);
        Log.i("HTML", "--> height = " + height);
        if (width <= newWidth) {
            return bitmap;
        }
        if (scale) {
            return Bitmap.createBitmap(bitmap, 0, 0, newWidth, height);
        }
        int width2 = height * newWidth;
        int scaleWidth = width2 / width;
        Matrix matrix = new Matrix();
        matrix.postScale((float) newWidth / width, (float) scaleWidth / height);
        return Bitmap.createBitmap(bitmap, 0, 0, width, height, matrix, true);
    }
}
