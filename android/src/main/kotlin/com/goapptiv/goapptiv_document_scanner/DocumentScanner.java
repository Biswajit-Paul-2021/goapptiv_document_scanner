package com.goapptiv.goapptiv_document_scanner;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.IntentSender;
import android.content.SharedPreferences;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanner;
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;

import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

public class DocumentScanner implements MethodChannel.MethodCallHandler,
        PluginRegistry.ActivityResultListener {

    private static final String START = "vision#startDocumentScanner";
    private static final String CLOSE = "vision#closeDocumentScanner";
    private static final String TAKE_LOST_RESULT = "vision#takeLostScanResult";
    private static final String LOST_RESULT_AVAILABLE = "vision#lostScanResultAvailable";
    private static final String TAG = "DocumentScanner";
    private static final String PREFS_NAME = "goapptiv_document_scanner";
    private static final String KEY_LOST_RESULT = "lost_scan_result";
    private static final String KEY_PENDING_TAG = "pending_scan_tag";
    private final Map<String, GmsDocumentScanner> instances = new HashMap<>();
    private final Context context;
    private final MethodChannel channel;
    private ActivityPluginBinding binding;
    final private int START_DOCUMENT_ACTIVITY = 0x362738;
    private MethodChannel.Result pendingResult = null;

    public DocumentScanner(@NonNull Context context, @NonNull MethodChannel channel) {
        this.context = context.getApplicationContext();
        this.channel = channel;
    }

    public void attachToActivity(@NonNull ActivityPluginBinding binding) {
        detachFromActivity();
        this.binding = binding;
        binding.addActivityResultListener(this);
    }

    public void detachFromActivity() {
        if (binding != null) {
            binding.removeActivityResultListener(this);
            binding = null;
        }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        String method = call.method;
        switch (method) {
            case START:
                handleScanner(call, result);
                break;
            case CLOSE:
                closeScanner(call);
                result.success(null);
                break;
            case TAKE_LOST_RESULT:
                result.success(takeLostResult());
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void handleScanner(MethodCall call, final MethodChannel.Result result) {
        if (pendingResult != null) {
            result.error(TAG, "Document scanner is already active", null);
            return;
        }
        Activity activity = binding != null ? binding.getActivity() : null;
        if (activity == null) {
            result.error(TAG, "No activity available", null);
            return;
        }

        String id = call.argument("id");
        GmsDocumentScanner scanner = instances.get(id);

        // Create a new scanner instance if it doesn't exist
        if (scanner == null) {
            Map<String, Object> options = call.argument("options");
            if (options == null) {
                result.error(TAG, "Invalid options", null);
                return;
            }
            GmsDocumentScannerOptions scannerOptions = parseOptions(options);
            scanner = GmsDocumentScanning.getClient(scannerOptions);
            instances.put(id, scanner);
        }

        // Written to disk, not kept in memory, so the tag still matches the scan
        // if the system kills the app before the scan finishes.
        String tag = call.argument("tag");
        SharedPreferences.Editor editor = prefs().edit();
        if (tag != null) {
            editor.putString(KEY_PENDING_TAG, tag);
        } else {
            editor.remove(KEY_PENDING_TAG);
        }
        editor.commit();

        pendingResult = result;
        scanner.getStartScanIntent(activity)
                .addOnSuccessListener(new OnSuccessListener<IntentSender>() {
                    @Override
                    public void onSuccess(IntentSender intentSender) {
                        try {
                            activity.startIntentSenderForResult(intentSender,
                                    START_DOCUMENT_ACTIVITY, null, 0, 0, 0);
                        } catch (IntentSender.SendIntentException e) {
                            finishWithError("Failed to start document scanner");
                        }
                    }
                }).addOnFailureListener(new OnFailureListener() {
                    @Override
                    public void onFailure(@NonNull Exception e) {
                        finishWithError("Failed to start document scanner");
                    }
                });
    }

    private void closeScanner(MethodCall call) {
        String id = call.argument("id");
        GmsDocumentScanner scanner = instances.get(id);
        if (scanner == null) return;
        instances.remove(id);
    }

    private GmsDocumentScannerOptions parseOptions(Map<String, Object> options) {
        boolean isGalleryImportAllowed = Boolean.TRUE.equals(options.get("isGalleryImport"));
        Integer pageLimit = Optional.ofNullable(options.get("pageLimit"))
                .filter(Integer.class::isInstance).map(Integer.class::cast).orElse(1);
        String baseMode = Objects.toString(options.get("mode"), "base");
        int format;
        switch ((String) Objects.requireNonNull(options.get("format"))) {
            case "pdf" -> format = GmsDocumentScannerOptions.RESULT_FORMAT_PDF;
            case "jpeg" -> format = GmsDocumentScannerOptions.RESULT_FORMAT_JPEG;
            default -> throw new IllegalArgumentException("Not a format:" + options.get("format"));
        }
        int mode = switch (baseMode) {
            case "filter" -> GmsDocumentScannerOptions.SCANNER_MODE_BASE_WITH_FILTER;
            case "full" -> GmsDocumentScannerOptions.SCANNER_MODE_FULL;
            default -> GmsDocumentScannerOptions.SCANNER_MODE_BASE;
        };
        GmsDocumentScannerOptions.Builder builder =
                new GmsDocumentScannerOptions.Builder().setGalleryImportAllowed(
                        isGalleryImportAllowed).setPageLimit(pageLimit).setResultFormats(format)
                .setScannerMode(mode);
        return builder.build();
    }

    private Map<String, Object> toResultMap(GmsDocumentScanningResult result) {
        Map<String, Object> resultMap = new HashMap<>();

        GmsDocumentScanningResult.Pdf pdf = result.getPdf();
        if (pdf != null) {
            Map<String, Object> pdfMap = new HashMap<>();
            pdfMap.put("pageCount", pdf.getPageCount());
            pdfMap.put("uri", pdf.getUri().getPath());
            resultMap.put("pdf", pdfMap);
        } else {
            resultMap.put("pdf", null);
        }

        List<GmsDocumentScanningResult.Page> pages = result.getPages();
        if (pages != null && !pages.isEmpty()) {
            List<String> imageUris = new ArrayList<>();
            for (GmsDocumentScanningResult.Page page : pages) {
                imageUris.add(page.getImageUri().getPath());
            }
            resultMap.put("images", imageUris);
        } else {
            resultMap.put("images", null);
        }
        resultMap.put("tag", prefs().getString(KEY_PENDING_TAG, null));
        return resultMap;
    }

    private void clearPendingTag() {
        prefs().edit().remove(KEY_PENDING_TAG).commit();
    }

    private void handleScanningResult(GmsDocumentScanningResult result) {
        MethodChannel.Result callback = pendingResult;
        pendingResult = null;
        callback.success(toResultMap(result));
    }

    /**
     * Keeps a scan result whose Dart caller is gone, which happens when the system
     * kills the app, or destroys its activity together with the Flutter engine,
     * while the scanner is open. The result is written to disk so that it also
     * survives the process being restarted, then Dart is told it can collect it.
     */
    private void keepLostResult(GmsDocumentScanningResult result) {
        String json = new JSONObject(toResultMap(result)).toString();
        // commit() rather than apply(): the process may be killed again soon,
        // and this is the only copy of the user's scan.
        prefs().edit().putString(KEY_LOST_RESULT, json).commit();
        // Dart only reacts if the app listens to recoveredScanResults. If it is
        // not listening yet, the result stays stored until it starts listening.
        channel.invokeMethod(LOST_RESULT_AVAILABLE, null);
    }

    /**
     * Returns the stored lost result and removes it, so each result is handed
     * out once. Files the system has since deleted from the cache are dropped.
     */
    @Nullable
    private Map<String, Object> takeLostResult() {
        SharedPreferences prefs = prefs();
        String json = prefs.getString(KEY_LOST_RESULT, null);
        if (json == null) return null;
        prefs.edit().remove(KEY_LOST_RESULT).commit();

        try {
            JSONObject stored = new JSONObject(json);

            Map<String, Object> pdfMap = null;
            JSONObject pdf = stored.optJSONObject("pdf");
            if (pdf != null && fileExists(pdf.optString("uri", null))) {
                pdfMap = new HashMap<>();
                pdfMap.put("pageCount", pdf.getInt("pageCount"));
                pdfMap.put("uri", pdf.getString("uri"));
            }

            List<String> images = new ArrayList<>();
            JSONArray storedImages = stored.optJSONArray("images");
            if (storedImages != null) {
                for (int i = 0; i < storedImages.length(); i++) {
                    String path = storedImages.optString(i, null);
                    if (fileExists(path)) images.add(path);
                }
            }

            if (pdfMap == null && images.isEmpty()) return null;
            Map<String, Object> resultMap = new HashMap<>();
            resultMap.put("pdf", pdfMap);
            resultMap.put("images", images.isEmpty() ? null : images);
            resultMap.put("tag", stored.isNull("tag") ? null : stored.getString("tag"));
            return resultMap;
        } catch (JSONException e) {
            return null;
        }
    }

    private static boolean fileExists(@Nullable String path) {
        return path != null && new File(path).exists();
    }

    private SharedPreferences prefs() {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    private void finishWithError(String message) {
        if (pendingResult == null) return;
        MethodChannel.Result result = pendingResult;
        pendingResult = null;
        result.error(TAG, message, null);
    }


    @Override
    public boolean onActivityResult(int requestCode, int resultCode, @Nullable Intent intent) {
        if (requestCode == START_DOCUMENT_ACTIVITY) {
            try {
                deliverActivityResult(resultCode, intent);
            } finally {
                // The scan is over either way; its tag is now in the result, if any.
                clearPendingTag();
            }
            return true;
        }
        return false;
    }

    private void deliverActivityResult(int resultCode, @Nullable Intent intent) {
        if (pendingResult == null) {
            // The Dart call that started this scan no longer exists, e.g. the
            // app was killed while the scanner was open. Keep a finished scan
            // so it can be delivered through recoveredScanResults.
            if (resultCode == Activity.RESULT_OK) {
                GmsDocumentScanningResult result =
                        GmsDocumentScanningResult.fromActivityResultIntent(intent);
                if (result != null) keepLostResult(result);
            }
            return;
        }
        if (resultCode == Activity.RESULT_OK) {
            GmsDocumentScanningResult result =
                    GmsDocumentScanningResult.fromActivityResultIntent(intent);
            if (result != null) {
                handleScanningResult(result);
            } else {
                finishWithError("Invalid scan result");
            }
        } else if (resultCode == Activity.RESULT_CANCELED) {
            finishWithError("Operation cancelled");
        } else {
            finishWithError("Unknown Error");
        }
    }
}
