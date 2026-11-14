import 'package:flutter_test/flutter_test.dart';
import 'package:stratus/models/ui_block.dart';

void main() {
  test('parses a line chart block from JSON', () {
    final block = UiBlock.fromJson({
      'type': 'line_chart',
      'title': 'Latency',
      'unit': 'ms',
      'labels': ['a', 'b'],
      'series': [
        {'name': 'p95', 'values': [1, 2]}
      ],
      'highlight_from': 1,
    });
    expect(block, isA<LineChartBlock>());
    expect((block as LineChartBlock).series.first.values, [1.0, 2.0]);
  });

  test('unknown block types degrade to a warning', () {
    final block = UiBlock.fromJson({'type': 'hologram'});
    expect(block, isA<FindingBlock>());
  });
}
