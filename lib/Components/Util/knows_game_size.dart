import 'package:flame/components.dart';

mixin KnowsGameSize on Component {
  late Vector2 gameSize;

  // ignore: must_call_super, annotate_overrides
  void onGameResize(Vector2 newGameSize) {
    gameSize = newGameSize;
  }
}
