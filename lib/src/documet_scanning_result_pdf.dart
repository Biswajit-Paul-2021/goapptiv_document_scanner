class DocumentScanningResultPdf {
  /// Returns the number of page being scanned.
  final int pageCount;

  /// Returns the PDF file Uri.
  final String uri;

  /// Constructor to create an instance of [DocumentScanningResultPdf].
  DocumentScanningResultPdf({required this.pageCount, required this.uri});

  /// Returns an instance of [DocumentScanningResultPdf] from a given [json].
  factory DocumentScanningResultPdf.fromJson(Map<dynamic, dynamic> json) {
    return DocumentScanningResultPdf(
        pageCount: json['pageCount'], uri: json['uri']);
  }

  @override
  String toString() {
    return '{pageCount: $pageCount, uri: $uri}';
  }
}
