import 'dart:ui';

import 'package:csslib/parser.dart' as parser;
import 'package:csslib/visitor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_html/src/styled_element.dart';
import 'package:flutter_html/style.dart';
import 'package:html/src/query_selector.dart';

Map<String, Style> cssToStyles(StyleSheet sheet) {
  sheet.topLevels.forEach((treeNode) {
    if (treeNode is RuleSet) {
      print(treeNode.selectorGroup.selectors.first.simpleSelectorSequences.first.simpleSelector.name);
    }
  });
}

class FontFaceDirectiveVisitor extends Visitor {
  final String fontFamily;
  final int fontWeight;
  final String fontStyle;

  String _currentProperty;
  String _directiveFontFamily;
  int _directiveFontWeight;
  String _directiveFontStyle;
  String _directiveSrc;

  FontFaceDirectiveVisitor(this.fontFamily, this.fontWeight, this.fontStyle);

  String getSrc(FontFaceDirective directive) {
    directive.visit(this);

    // print('getSrc:');
    // print('expected: $fontFamily, $fontWeight, $fontStyle');
    // print('found:    $_directiveFontFamily, $_directiveFontWeight, $_directiveFontStyle');
    if (fontFamily == _directiveFontFamily && fontWeight == _directiveFontWeight && (fontStyle == null || fontStyle == _directiveFontStyle)) {
//      && fontWeight == _directiveFontWeight && fontStyle == _directiveFontStyle) {
      return _directiveSrc;
    }

    return null;
  }

  @override
  void visitDeclaration(Declaration node) {
    // print('visitDeclaration(${node.span.text})');
    _currentProperty = node.property;
    node.expression.visit(this);
    node.dartStyle?.visit(this);
  }

  @override
  void visitLiteralTerm(LiteralTerm node) {
    // print('FontFaceDirectiveVisitor.visitLiteralTerm(${node.text})');
    switch (_currentProperty) {
//      case 'font-family':
//        _directiveFontFamily = node.text;
//        break;
//      case 'font-weight':
//        _directiveFontWeight = node.text;
//        break;
      case 'font-style':
        _directiveFontStyle = node.text;
        break;
    }
  }

  @override
  void visitFontExpression(FontExpression node) {
    // print('FontFaceDirectiveVisitor.visitFontExpression(${node.span.text})');
    if (node.font.family.isNotEmpty) {
      _directiveFontFamily = node.font.family.first;
    }

    _directiveFontWeight = node.font.weight;
  }

  @override
  void visitUriTerm(UriTerm node) {
    // print('FontFaceDirectiveVisitor.visitUriTerm(${node.text})');
    switch (_currentProperty) {
      case 'src':
        _directiveSrc = node.text;
        break;
    }
  }
}

class DeclarationVisitor extends Visitor {
  final StyledElement element;
  final bool isInline;
  final List<FontFaceDirective> _fontFaceDirectives = [];
  String _currentProperty;
  String _currentFontStyle;

  DeclarationVisitor({this.element, this.isInline = false}) {
  // print('\nDeclarationVisitor(<${element?.name} id="${element?.elementId}" class="${element?.elementClasses?.join(' ')}" ${element?.attributes?.entries?.map((entry) => '[${entry.key}=${entry.value}]')?.join(' ')}');
  }

  void applyDeclarations(StyleSheet sheet) {
    sheet.visit(this);
  }

  @override
  void visitRuleSet(RuleSet node) {
    // print('visitRuleSet(${node.span.text})');
    if (element == null || (element.element != null && matches(element.element, node.span.text))) {
      visitDeclarationGroup(node.declarationGroup);
    }
  }

  @override
  void visitDeclaration(Declaration node) {
    // print('visitDeclaration(${node.span.text})');
    if (node.property != 'src') {
      _currentProperty = node.property;
    }
    super.visitDeclaration(node);
//    node.dartStyle?.visit(this);
  }

  @override
  void visitFontFaceDirective(FontFaceDirective node) {
    _fontFaceDirectives.add(node);
  }

  @override
  void visitExpressions(Expressions node) {
    // print('visitExpressions(${node.span.text})');
    node.expressions.forEach((expression) {
      expression.visit(this);
      //_result[_currentProperty].add(expression);
    });
  }

  @override
  void visitEmTerm(EmTerm node) {
    // print('visitEmTerm(${node.text})');
    switch (_currentProperty) {
      case 'font-size':
        element.style.fontSize = FontSize(FontSize.medium.size * double.parse(node.text));
    }
  }

  @override
  void visitLiteralTerm(LiteralTerm node) {
    // print('visitLiteralTerm(${node.text})');
    switch (_currentProperty) {
      case 'direction':
        element.style.direction = ExpressionMapping.expressionToDirection(node);
        break;
      case 'display':
        element.style.display = ExpressionMapping.expressionToDisplay(node);
        break;
      case 'text-align':
        element.style.textAlign = ExpressionMapping.expressionToTextAlign(node);
        break;
      case 'text-transform':
        element.style.textTransform = ExpressionMapping.expressionToTextTransform(node);
        break;
      case 'font-style':
        _currentFontStyle = node.text;
        element.style.fontStyle = ExpressionMapping.expressionToFontStyle(node);
        break;
    }
  }

  @override
  void visitHexColorTerm(HexColorTerm node) {
    // print('visitHexColorTerm');
    switch (_currentProperty) {
      case 'background-color':
        element.style.backgroundColor = ExpressionMapping.expressionToColor(node);
        break;
      case 'color':
        element.style.color = ExpressionMapping.expressionToColor(node);
        break;
    }
  }

  @override
  void visitLengthTerm(LengthTerm node) {
    // print('visitLengthTerm(${node.text})');
    if (node.unit != parser.TokenKind.UNIT_LENGTH_PX) {
      // TODO support other unit types
      return;
    }

    switch (_currentProperty) {
      case 'margin-left':
        visitMarginExpression(MarginExpression(node.span, left: node.value));
        break;
      case 'margin-top':
        visitMarginExpression(MarginExpression(node.span, top: node.value));
        break;
      case 'margin-right':
        visitMarginExpression(MarginExpression(node.span, right: node.value));
        break;
      case 'margin-bottom':
        visitMarginExpression(MarginExpression(node.span, bottom: node.value));
        break;
      case 'text-indent':
        element.style.textIndent = node.value.toDouble();
        break;
    }
  }

  @override
  void visitNumberTerm(NumberTerm node) {
    // print('visitNumberTerm(${node.text})');
    switch (_currentProperty) {
      case 'margin-left':
        visitMarginExpression(MarginExpression(node.span, left: node.value));
        break;
      case 'margin-top':
        visitMarginExpression(MarginExpression(node.span, top: node.value));
        break;
      case 'margin-right':
        visitMarginExpression(MarginExpression(node.span, right: node.value));
        break;
      case 'margin-bottom':
        visitMarginExpression(MarginExpression(node.span, bottom: node.value));
        break;
      case 'text-indent':
        element.style.textIndent = node.value.toDouble();
        break;
    }
  }

  @override
  void visitUriTerm(UriTerm node) {
    // print('visitUriTerm(${node.text})');
    switch (_currentProperty) {
      case 'font-weight':
        if (element.style.fontFamily == null) element.style.fontFamily = ExpressionMapping.expressionToFontFamily(node);
        break;
    }
  }

  @override
  void visitFontExpression(FontExpression node) {
    // print('visitFontExpression(${node.span.text})');
    if (node.font.family?.isNotEmpty == true) {
      element.style.fontFamily = node.font.family.first;
    }
    element.style.fontWeight = ExpressionMapping.expressionToFontWeight(node);

    for (var fontFaceDirective in _fontFaceDirectives) {
      if (node.font?.family == null) {
        continue;
      }
      for (var fontFamily in node.font?.family) {
        final foundFontFaceSrc = FontFaceDirectiveVisitor(fontFamily, node.font.weight, _currentFontStyle).getSrc(fontFaceDirective);
        if (foundFontFaceSrc != null) {
          element.style.fontFamily = foundFontFaceSrc;
          return;
        }
      }
    }
  }

  @override
  void visitBoxExpression(BoxExpression node) {
    // print('visitBoxExpression(${node.span.text})');
  }

  @override
  void visitMarginGroup(MarginGroup node) {
    // print('visitMarginGroup(${node.span.text})');
  }

  @override
  void visitMarginExpression(MarginExpression node) {
    // print('visitMarginExpression(${node.box.left} ${node.box.top} ${node.box.right} ${node.box.bottom})');
    final box = node.box;

    if (element.style.margin == null) {
      element.style.margin = EdgeInsets.fromLTRB(box.left?.toDouble() ?? 0, box.top?.toDouble() ?? 0, box.right?.toDouble() ?? 0, box.bottom?.toDouble() ?? 0);
    } else {
      if (box.left != null) {
        element.style.margin = element.style.margin.copyWith(left: box.left.toDouble());
      }

      if (box.top != null) {
        element.style.margin = element.style.margin.copyWith(top: box.top.toDouble());
      }

      if (box.right != null) {
        element.style.margin = element.style.margin.copyWith(right: box.right.toDouble());
      }

      if (box.bottom != null) {
        element.style.margin = element.style.margin.copyWith(bottom: box.bottom.toDouble());
      }
    }
  }

  @override
  void visitBorderExpression(BorderExpression node) {
    // print('visitBorderExpression(${node.span.text})');
  }

  @override
  void visitHeightExpression(HeightExpression node) {
    // print('visitHeightExpression(${node.span.text})');
  }

  @override
  void visitPaddingExpression(PaddingExpression node) {
    // print('visitPaddingExpression(${node.span.text})');
    final box = node.box;
    element.style.padding = EdgeInsets.fromLTRB(box.left.toDouble(), box.top.toDouble(), box.right.toDouble(), box.bottom.toDouble());
  }

  @override
  void visitWidthExpression(WidthExpression node) {
    // print('visitWidthExpression(${node.span.text})');
  }
}

//Mapping functions
class ExpressionMapping {
  static Color expressionToColor(Expression value) {
    if (value is HexColorTerm) {
      return stringToColor(value.text);
    }
    //TODO(Sub6Resources): Support function-term values (rgba()/rgb())
    return null;
  }

  static Color stringToColor(String _text) {
    var text = _text.replaceFirst('#', '');
    if (text.length == 3) {
      text = text.replaceAllMapped(RegExp(r"[a-fA-F]|\d"), (match) => '${match.group(0)}${match.group(0)}');
    }
    int color = int.parse(text, radix: 16);

    if (color <= 0xffffff) {
      return new Color(color).withAlpha(255);
    } else {
      return new Color(color);
    }
  }

  static TextAlign expressionToTextAlign(Expression value) {
    if (value is LiteralTerm) {
      switch (value.text) {
        case "center":
          return TextAlign.center;
        case "left":
          return TextAlign.left;
        case "right":
          return TextAlign.right;
        case "justify":
          return TextAlign.justify;
        case "end":
          return TextAlign.end;
        case "start":
          return TextAlign.start;
      }
    }
    return TextAlign.start;
  }

  static EdgeInsets expressionToPadding(Expression value) {
    if (value is PaddingExpression) {
      final box = (value as PaddingExpression).box;
      return EdgeInsets.fromLTRB(box.left, box.top, box.right, box.bottom);
    }
    return EdgeInsets.zero;
  }

  static TextDirection expressionToDirection(Expression value) {
    if (value is LiteralTerm) {
      switch (value.text) {
        case "ltr":
          return TextDirection.ltr;
        case "rtl":
          return TextDirection.rtl;
      }
    }
    return TextDirection.ltr;
  }

  static List<FontFeature> expressionToFontFeatureSettings(List<Expression> value) {
    //TODO
    return [];
  }

  static List<Shadow> expressionToTextShadow(List<Expression> value) {
    //TODO
    return [];
  }

  static Display expressionToDisplay(Expression value) {
    if (value is LiteralTerm) {
      switch (value.text) {
        case 'block':
          return Display.BLOCK;
        case 'inline-block':
          return Display.INLINE_BLOCK;
        case 'inline':
          return Display.INLINE;
        case 'list-item':
          return Display.LIST_ITEM;
      }
    }
  }

  static FontStyle expressionToFontStyle(Expression value) {
    if (value is LiteralTerm) {
      switch (value.text) {
        case 'normal':
          return FontStyle.normal;
        case 'italic':
          return FontStyle.italic;
        case 'oblique':
          return FontStyle.italic;
      }
    }
  }

  static FontWeight expressionToFontWeight(FontExpression value) {
    if (value is FontExpression) {
      switch (value.font.weight) {
        case 100:
          return FontWeight.w100;
        case 200:
          return FontWeight.w200;
        case 300:
          return FontWeight.w300;
        case 400:
          return FontWeight.w400;
        case 500:
          return FontWeight.w500;
        case 600:
          return FontWeight.w600;
        case 700:
          return FontWeight.w700;
        case 800:
          return FontWeight.w800;
        case 900:
          return FontWeight.w900;
      }
    }
  }

  static TextTransform expressionToTextTransform(Expression value) {
    if (value is LiteralTerm) {
      switch (value.text) {
        case 'none':
          return TextTransform.none;
        case 'capitalize':
          return TextTransform.capitalize;
        case 'uppercase':
          return TextTransform.uppercase;
        case 'lowercase':
          return TextTransform.lowercase;
      }
    }
  }

  static String expressionToFontFamily(Expression value) {
    if (value is LiteralTerm) {
      // print('expressionToFontFamily(${value.text})');
      return value.text;
    } else {
      // print('expressionToFontFamily(${value.span.text})');
      return value.span.text;
    }
  }
}
