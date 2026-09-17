import 'package:goapptiv_document_scanner/src/documet_scanning_result_pdf.dart';


class DocumentScanningResult {
  /// Returns the PDF result or null if `DocumentFormat.pdf` was not specified when creating the scanner options.
  final DocumentScanningResultPdf? pdf;

  /// Returns the scanned images or null if `DocumentFormat.jpeg` was not specified when creating the scanner options.
  final List<String> images;

  /// Constructor to create an instance of [DocumentScanningResult].
  DocumentScanningResult({required this.pdf, required this.images});

  /// Returns an instance of [DocumentScanningResult] from a given [json].
  factory DocumentScanningResult.fromJson(Map<dynamic, dynamic> json) {
    final images = json['images'] != null
        ? List<String>.from(json['images'] as List)
        : <String>[];
    final pdf = json['pdf'] != null
        ? DocumentScanningResultPdf.fromJson(json['pdf'])
        : null;
    return DocumentScanningResult(pdf: pdf, images: images);
  }

  @override
  String toString() {
    return '{pdf: $pdf, images: $images}';
  }
}
