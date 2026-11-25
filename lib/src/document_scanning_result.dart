import 'package:goapptiv_document_scanner/src/documet_scanning_result_pdf.dart';


class DocumentScanningResult {
  /// Returns the PDF result or null if `DocumentFormat.pdf` was not specified when creating the scanner options.
  final DocumentScanningResultPdf? pdf;

  /// Returns the scanned images or null if `DocumentFormat.jpeg` was not specified when creating the scanner options.
  final List<String> images;

  /// The `tag` passed to `scanDocument()` for this scan, if any.
  ///
  /// Use it to tell which screen, form field or record a scan belongs to,
  /// especially for scans arriving through `recoveredScanResults`.
  final String? tag;

  /// Constructor to create an instance of [DocumentScanningResult].
  DocumentScanningResult({required this.pdf, required this.images, this.tag});

  /// Returns an instance of [DocumentScanningResult] from a given [json].
  factory DocumentScanningResult.fromJson(Map<dynamic, dynamic> json) {
    final images = json['images'] != null
        ? List<String>.from(json['images'] as List)
        : <String>[];
    final pdf = json['pdf'] != null
        ? DocumentScanningResultPdf.fromJson(json['pdf'])
        : null;
    return DocumentScanningResult(
      pdf: pdf,
      images: images,
      tag: json['tag'] as String?,
    );
  }

  @override
  String toString() {
    return '{pdf: $pdf, images: $images, tag: $tag}';
  }
}
