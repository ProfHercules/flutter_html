import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_html/html_parser.dart';
import 'package:flutter_html/src/html_elements.dart';
import 'package:flutter_html/src/styled_element.dart';
import 'package:flutter_html/style.dart';
import 'package:html/dom.dart' as dom;

import 'styled_element.dart';

/// A [LayoutElement] is an element that breaks the normal Inline flow of
/// an html document with a more complex layout. LayoutElements handle
abstract class LayoutElement extends StyledElement {
  LayoutElement({
    String name,
    List<StyledElement> children,
    Style style,
    dom.Element node,
  }) : super(name: name, children: children, style: style, node: node);

  Widget toWidget(RenderContext context);
}

class TableLayoutElement extends LayoutElement {
  TableLayoutElement({
    String name,
    Style style,
    @required List<StyledElement> children,
    dom.Element node,
  }) : super(name: name, style: style, children: children, node: node);

  @override
  Widget toWidget(RenderContext context) {
    final colWidths = children
        .where((c) => c.name == "colgroup")
        .map((group) {
          return group.children.where((c) => c.name == "col").map((c) {
            final widthStr = c.attributes["width"] ?? "";
            if (widthStr.endsWith("%")) {
              final width =
                  double.tryParse(widthStr.substring(0, widthStr.length - 1)) *
                      0.01;
              return FractionColumnWidth(width);
            } else {
              final width = double.tryParse(widthStr);
              return FixedColumnWidth(width);
            }
          });
        })
        .expand((i) => i)
        .toList()
        .asMap();

    return Container(
        decoration: BoxDecoration(
          color: style.backgroundColor,
          border: style.border,
        ),
        width: style.width,
        height: style.height,
        child: Table(
          columnWidths: colWidths,
          children: children
              .map((c) {
                if (c is TableSectionLayoutElement) {
                  return c.toTableRows(context);
                }
                return null;
              })
              .where((t) {
                return t != null;
              })
              .toList()
              .expand((i) => i)
              .toList(),
        ));
  }
}

class TableSectionLayoutElement extends LayoutElement {
  TableSectionLayoutElement({
    String name,
    @required List<StyledElement> children,
  }) : super(name: name, children: children);

  @override
  Widget toWidget(RenderContext context) {
    return Container(child: Text("TABLE SECTION"));
  }

  List<TableRow> toTableRows(RenderContext context) {
    final rawHtmlElements = children.whereType<TableRowLayoutElement>();
    final tableRowLayoutElements = <TableRowLayoutElement>[];
    rawHtmlElements.forEach((row) {
      final newChildren = row.children
          .whereType<StyledElement>()
          .where((c) => (c.name == 'td' || c.name == 'th'))
          .toList();
      row.children = newChildren;
      tableRowLayoutElements.add(row);
    });

    final maxChildCount =
        tableRowLayoutElements.map((c) => c.children.length).reduce(max);

    return tableRowLayoutElements
        // .where((e) => e.children.length == maxChildCount)
        .map((tr) => tr.toTableRow(context, maxChildCount))
        .toList();
  }
}

class TableRowLayoutElement extends LayoutElement {
  TableRowLayoutElement({
    String name,
    @required List<StyledElement> children,
    dom.Element node,
  }) : super(name: name, children: children, node: node);

  @override
  Widget toWidget(RenderContext context) {
    return Container(child: Text("TABLE ROW"));
  }

  List<String> _splitTitle(String title, int count) {
    final split = title.split(" ");
    final partCount = split.length;
    if (partCount == count) return split;
    if (partCount < count) {
      final diff = count - partCount;
      var before = (diff * 0.5).floor();
      var after = (diff * 0.5).ceil();
      while (before > 0) {
        split.insert(0, "");
        before -= 1;
      }
      while (after > 0) {
        split.add("");
        after -= 1;
      }
      return split;
    } else {
      return split.sublist(0, count - 1);
    }
  }

  TableRow toTableRow(RenderContext context, [int childCountTarget]) {
    var styledElemChildren = <Widget>[];

    if (children.length != 1) {
      styledElemChildren = children.whereType<StyledElement>().map((c) {
        if (c.name == 'td' || c.name == 'th') {
          return TableCell(
            child: Container(
              padding: c.style.padding,
              decoration: BoxDecoration(
                color: c.style.backgroundColor,
                border: c.style.border,
              ),
              child: StyledText(
                textSpan: context.parser.parseTree(context, c),
                style: c.style,
              ),
            ),
          );
        } else {
          return Container();
        }
      }).toList();
    }

    if (styledElemChildren.length < childCountTarget) {
      final diff = childCountTarget - styledElemChildren.length;
      var before = (diff * 0.5).floor();
      var after = (diff * 0.5).ceil();
      while (before > 0) {
        styledElemChildren.insert(0, Container());
        before -= 1;
      }
      while (after > 0) {
        styledElemChildren.add(Container());
        after -= 1;
      }
    }

    return TableRow(
      decoration: BoxDecoration(
        border: style.border,
        color: style.backgroundColor,
      ),
      children: styledElemChildren,
    );
  }
}

class TableStyleElement extends StyledElement {
  TableStyleElement({
    String name,
    List<StyledElement> children,
    Style style,
    dom.Element node,
  }) : super(name: name, children: children, style: style, node: node);
}

TableStyleElement parseTableDefinitionElement(
  dom.Element element,
  List<StyledElement> children,
) {
  switch (element.localName) {
    case "colgroup":
    case "col":
      return TableStyleElement(
        name: element.localName,
        children: children,
        node: element,
      );
    default:
      return TableStyleElement();
  }
}

LayoutElement parseLayoutElement(
  dom.Element element,
  List<StyledElement> children,
) {
  switch (element.localName) {
    case "table":
      return TableLayoutElement(
        name: element.localName,
        children: children,
        node: element,
      );
      break;
    case "thead":
    case "tbody":
    case "tfoot":
      return TableSectionLayoutElement(
        name: element.localName,
        children: children,
      );
      break;
    case "tr":
      return TableRowLayoutElement(
        name: element.localName,
        children: children,
        node: element,
      );
      break;
    default:
      return TableLayoutElement(children: children);
  }
}
