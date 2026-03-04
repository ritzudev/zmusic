/// Estado global simple para saber si el usuario está escribiendo en algún campo.
/// Se actualiza explícitamente desde los FocusNodes de los TextFields,
/// evitando problemas de timing al detectar el foco durante keypresses.
class TypingState {
  TypingState._();

  static bool isTyping = false;
}
