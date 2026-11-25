enum DocumentFormat {
  pdf(name: 'pdf'),
  jpeg(name: 'jpeg');

  final String name;

  const DocumentFormat({required this.name});
}

enum ScannerMode {
  baseMode(name: 'base'),
  filterMode(name: 'filter'),
  fullMode(name: 'full');

  final String name;

  const ScannerMode({required this.name});
}

class DocumentScannerOptions {
  /// Constructor for [DocumentScannerOptions].
  DocumentScannerOptions({
    this.documentFormat = DocumentFormat.jpeg,
    this.pageLimit = 1,
    this.mode = ScannerMode.baseMode,
    this.isGalleryImport = false,
  });

  /// Sets a page limit for the maximum number of pages that can be scanned in a single scanning session. default = 1.
  final int pageLimit;

  /// Sets scanner result formats.
  /// Available formats: PDF, JPG and default format is JPG.
  final DocumentFormat documentFormat;

  /// Sets the scanner mode which determines what features are enabled. default = ScannerModel.full.
  final ScannerMode mode;

  /// Enable or disable the capability to import from the photo gallery. default = false.
  final bool isGalleryImport;

  /// Returns a json representation of an instance of [DocumentScannerOptions].
  Map<String, dynamic> toJson() => {
        'pageLimit': pageLimit,
        'format': documentFormat.name,
        'mode': mode.name,
        'isGalleryImport': isGalleryImport,
      };
}
