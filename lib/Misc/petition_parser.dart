enum PetitionFieldType { dropdown, text, multilineText, checkbox }

class PetitionFieldOption {
  final String value;
  final String label;
  final bool isSelected;

  const PetitionFieldOption({
    required this.value,
    required this.label,
    this.isSelected = false,
  });
}

class PetitionFormField {
  final String name;
  final String label;
  final PetitionFieldType type;
  final List<PetitionFieldOption> options;
  final String defaultValue;
  final bool isRequired;

  const PetitionFormField({
    required this.name,
    required this.label,
    required this.type,
    this.options = const [],
    this.defaultValue = '',
    this.isRequired = true,
  });
}

class PetitionParser {
  /// Extracts interactive form fields from Neptun request form pageHTML
  static List<PetitionFormField> parseFields(String html) {
    final List<PetitionFormField> fields = [];
    final Set<String> seenNames = {};

    // 1. Parse <select> dropdowns
    final selectRegExp = RegExp(
      r'<select[^>]*name=["\x27]([^"\x27]+)["\x27][^>]*>(.*?)</select>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final match in selectRegExp.allMatches(html)) {
      final name = match.group(1) ?? '';
      if (name.isEmpty || seenNames.contains(name)) continue;
      seenNames.add(name);

      final selectBody = match.group(2) ?? '';
      final options = _parseOptions(selectBody);
      final label = _extractLabelBefore(html, match.start);

      String defaultVal = '';
      for (var opt in options) {
        if (opt.isSelected) {
          defaultVal = opt.value;
          break;
        }
      }
      if (defaultVal.isEmpty && options.isNotEmpty) {
        defaultVal = options.first.value;
      }

      fields.add(PetitionFormField(
        name: name,
        label: label.isNotEmpty ? label : name,
        type: PetitionFieldType.dropdown,
        options: options,
        defaultValue: defaultVal,
      ));
    }

    // 2. Parse <textarea>
    final textareaRegExp = RegExp(
      r'<textarea[^>]*name=["\x27]([^"\x27]+)["\x27][^>]*>(.*?)</textarea>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final match in textareaRegExp.allMatches(html)) {
      final name = match.group(1) ?? '';
      if (name.isEmpty || seenNames.contains(name)) continue;
      seenNames.add(name);

      final defaultVal = (match.group(2) ?? '').trim();
      final label = _extractLabelBefore(html, match.start);

      fields.add(PetitionFormField(
        name: name,
        label: label.isNotEmpty ? label : name,
        type: PetitionFieldType.multilineText,
        defaultValue: defaultVal,
      ));
    }

    // 3. Parse <input> (text, checkbox)
    final inputRegExp = RegExp(
      r'<input[^>]+name=["\x27]([^"\x27]+)["\x27][^>]*>',
      caseSensitive: false,
    );

    for (final match in inputRegExp.allMatches(html)) {
      final fullTag = match.group(0) ?? '';
      final name = match.group(1) ?? '';
      if (name.isEmpty || seenNames.contains(name)) continue;

      final typeMatch = RegExp(r'type=["\x27]([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(fullTag);
      final typeStr = (typeMatch?.group(1) ?? 'text').toLowerCase();
      if (typeStr == 'hidden' || typeStr == 'submit' || typeStr == 'button') continue;

      seenNames.add(name);
      final valMatch = RegExp(r'value=["\x27]([^"\x27]*)["\x27]', caseSensitive: false).firstMatch(fullTag);
      final defaultVal = valMatch?.group(1) ?? '';
      final label = _extractLabelBefore(html, match.start);

      if (typeStr == 'checkbox') {
        final isChecked = fullTag.toLowerCase().contains('checked');
        fields.add(PetitionFormField(
          name: name,
          label: label.isNotEmpty ? label : name,
          type: PetitionFieldType.checkbox,
          defaultValue: isChecked ? 'true' : 'false',
        ));
      } else {
        fields.add(PetitionFormField(
          name: name,
          label: label.isNotEmpty ? label : name,
          type: PetitionFieldType.text,
          defaultValue: defaultVal,
        ));
      }
    }

    return fields;
  }

  static List<PetitionFieldOption> _parseOptions(String selectBody) {
    final List<PetitionFieldOption> options = [];
    final optionRegExp = RegExp(
      r'<option[^>]*value=["\x27]([^"\x27]*)["\x27][^>]*>(.*?)</option>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final match in optionRegExp.allMatches(selectBody)) {
      final value = match.group(1) ?? '';
      var text = match.group(2) ?? '';
      text = _cleanHtml(text);

      final fullTag = match.group(0) ?? '';
      final isSelected = fullTag.toLowerCase().contains('selected');

      options.add(PetitionFieldOption(
        value: value,
        label: text.isNotEmpty ? text : value,
        isSelected: isSelected,
      ));
    }
    return options;
  }

  /// Scans up to 400 characters backwards in html to find the enclosing or previous <td>/<th> label
  static String _extractLabelBefore(String html, int tagStartIndex) {
    final searchStart = tagStartIndex > 400 ? tagStartIndex - 400 : 0;
    final snippet = html.substring(searchStart, tagStartIndex);

    // Look for preceding <td>...</td> or <th>...</th>
    final cellMatches = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', caseSensitive: false, dotAll: true).allMatches(snippet);
    if (cellMatches.isNotEmpty) {
      final lastCell = cellMatches.last.group(1) ?? '';
      final cleaned = _cleanHtml(lastCell);
      if (cleaned.isNotEmpty) {
        // If it ends with something like "Félév:" or "Név:"
        final lines = cleaned.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
        if (lines.isNotEmpty) {
          return lines.last;
        }
        return cleaned;
      }
    }

    // Fallback: look for <label>...</label>
    final labelMatches = RegExp(r'<label[^>]*>(.*?)</label>', caseSensitive: false, dotAll: true).allMatches(snippet);
    if (labelMatches.isNotEmpty) {
      final cleaned = _cleanHtml(labelMatches.last.group(1) ?? '');
      if (cleaned.isNotEmpty) return cleaned;
    }

    return '';
  }

  static String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  /// Checks if pageHTML contains a base64 encoded document preview image
  static String? extractPreviewBase64(String html) {
    final match = RegExp(r'<img[^>]+src=["\x27]data:image/[^;]+;base64,([^"\x27]+)["\x27]', caseSensitive: false).firstMatch(html);
    if (match != null) {
      return match.group(1);
    }
    return null;
  }
}
