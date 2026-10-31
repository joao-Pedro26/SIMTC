/// Confere o e-mail com a mesma regra do servidor (o `@IsEmail` do
/// class-validator, desde a Fase 8D-1): o que passa aqui, o servidor aceita, e
/// o erro de digitação aparece na tela, antes do envio (Fase 8D). Ficam de
/// fora só formas que ninguém digita num formulário de inscrição (o nome entre
/// aspas antes do "@", o endereço IP entre colchetes).
bool isValidEmail(String value) => _email.hasMatch(value);

/// Cada pedaço do nome antes do "@": sem ponto no começo, no fim ou repetido.
const String _localAtom =
    r"[a-zA-Z0-9!#$%&'*+\-/=?^_`{|}~ -퟿豈-﷏ﷰ-￯]+";

/// Cada parte do domínio: letras (com acento), dígitos e hífen, sem hífen nas
/// pontas.
const String _label =
    r'[a-zA-Z0-9¡-￿](?:[a-zA-Z0-9¡-￿-]*[a-zA-Z0-9¡-￿])?';

/// O fim do domínio: duas letras ou mais, sem dígito ("com", "br").
const String _topLevel =
    r'(?:[a-zA-Z¡-¨ª-퟿豈-﷏ﷰ-￯]{2,}|xn[a-zA-Z0-9-]{2,})';

final RegExp _email =
    RegExp('^$_localAtom(?:\\.$_localAtom)*@(?:$_label\\.)+$_topLevel\$');
