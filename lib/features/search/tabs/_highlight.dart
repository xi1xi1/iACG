import 'package:flutter/material.dart';

TextSpan highlightText(String text, String kw, TextStyle normal, TextStyle highlight) {
  if (kw.isEmpty) return TextSpan(text: text, style: normal);
  final lower = text.toLowerCase();
  final k = kw.toLowerCase();
  final spans = <TextSpan>[];
  int start = 0;
  while (true) {
    final idx = lower.indexOf(k, start);
    if (idx < 0) {
      spans.add(TextSpan(text: text.substring(start), style: normal));
      break;
    }
    if (idx > start) spans.add(TextSpan(text: text.substring(start, idx), style: normal));
    spans.add(TextSpan(text: text.substring(idx, idx + k.length), style: highlight));
    start = idx + k.length;
  }
  return TextSpan(children: spans);
}
