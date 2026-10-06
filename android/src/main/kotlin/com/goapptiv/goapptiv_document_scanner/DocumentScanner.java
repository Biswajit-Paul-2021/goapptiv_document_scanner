package com.goapptiv.goapptiv_document_scanner;

import android.app.Activity;
import android.content.Intent;
import android.content.IntentSender;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.android.gms.tasks.OnFailureListener;
import com.google.android.gms.tasks.OnSuccessListener;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanner;
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning;
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult;

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
    private static final String TAG = "DocumentScanner";
    private final Map<String, GmsDocumentScanner> instances = new HashMap<>();
    private ActivityPluginBinding binding;
    final private int START_DOCUMENT_ACTIVITY = 0x362738;
    private MethodChannel.Result pendingResult = null;

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

    private void handleScanningResult(GmsDocumentScanningResult result) {
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

        MethodChannel.Result callback = pendingResult;
        pendingResult = null;
        callback.success(resultMap);
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
            // The caller may be gone, e.g. if the activity was recreated after process death
            if (pendingResult == null) return true;
            if (resultCode == Activity.RESULT_OK) {
                GmsDocumentScanningResult result =
                        GmsDocumentScanningResult.fromActivityResultIntent(
                        intent);
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
            return true;
        }
        return false;
    }
}
