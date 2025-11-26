String _replaceNamedEntities(String input) {
  final entities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&quot;': '"',
    '&apos;': "'",
    '&lt;': '<',
    '&gt;': '>',
    '&#8217;': '’',
    '&#39;': "'",
    '&#8230;': '…',
  };

  String out = input;
  entities.forEach((k, v) {
    out = out.replaceAll(k, v);
  });
  return out;
}

String _replaceNumericEntities(String input) {
  return input.replaceAllMapped(RegExp(r'&#(x?[0-9A-Fa-f]+);'), (m) {
    final code = m[1]!;
    try {
      final isHex = code.toLowerCase().startsWith('x');
      final intVal = int.parse(isHex ? code.substring(1) : code, radix: isHex ? 16 : 10);
      return String.fromCharCode(intVal);
    } catch (e) {
      return m[0]!;
    }
  });
}

String stripHtml(String? input) {
  if (input == null) return '';
  // Remove HTML tags
  var withoutTags = input.replaceAll(RegExp(r'<[^>]*>'), '');
  // Replace named entities
  withoutTags = _replaceNamedEntities(withoutTags);
  // Replace numeric entities (decimal & hex)
  withoutTags = _replaceNumericEntities(withoutTags);
  // Collapse multiple spaces
  return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String sanitizeForSearch(String? input) {
  return stripHtml(input).toLowerCase();
}
