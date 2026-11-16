import 'package:tech_vis/tech_vis.dart';

/// Width of one character, as a fraction of the requested height.
const fakeCharacterAspect = 0.5;

/// Stands in for an app's text layout: each character is
/// [fakeCharacterAspect] times the requested height wide, and the content
/// handle is the request itself, so a test can read back what was asked.
BillboardContent fakeTextResolver(TextRequest request) => BillboardContent(
  value: request,
  widthPixels: request.text.length * fakeCharacterAspect * request.heightPixels,
  heightPixels: request.heightPixels,
);
