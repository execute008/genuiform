import 'package:flutter_test/flutter_test.dart';
import 'package:genuiform/src/models/quiz_input_type.dart';

void main() {
  group('QuizInputType', () {
    test('all values exist', () {
      expect(QuizInputType.values.length, 7);
    });

    group('JSON wire values match spec §10.1', () {
      test('slider serialises as "slider"', () {
        expect(quizInputTypeToJson(QuizInputType.slider), 'slider');
      });

      test('choice serialises as "choice"', () {
        expect(quizInputTypeToJson(QuizInputType.choice), 'choice');
      });

      test('multiChoice serialises as "multiChoice"', () {
        expect(quizInputTypeToJson(QuizInputType.multiChoice), 'multiChoice');
      });

      test('text serialises as "text"', () {
        expect(quizInputTypeToJson(QuizInputType.text), 'text');
      });

      test('number serialises as "number"', () {
        expect(quizInputTypeToJson(QuizInputType.number), 'number');
      });

      test('date serialises as "date"', () {
        expect(quizInputTypeToJson(QuizInputType.date), 'date');
      });

      test('noneJustInformation serialises as "noneJustInformation"', () {
        expect(quizInputTypeToJson(QuizInputType.noneJustInformation), 'noneJustInformation');
      });
    });

    group('JSON round-trip', () {
      for (final value in QuizInputType.values) {
        test('${value.name} round-trips', () {
          final wire = quizInputTypeToJson(value);
          final restored = quizInputTypeFromJson(wire);
          expect(restored, value);
        });
      }
    });
  });
}
