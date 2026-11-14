import { buildParticipantUpdateData } from 'src/participants/participant-data.util';

describe('buildParticipantUpdateData', () => {
  it('só nome: os campos opcionais ficam undefined (o Prisma ignora no update)', () => {
    expect(buildParticipantUpdateData({ name: 'Maria Souza' })).toEqual({
      name: 'Maria Souza',
      email: undefined,
      cnhCategory: undefined,
      cnhExpiration: undefined,
    });
  });

  it('e-mail e CNH vazios viram undefined: não apagam o que está no banco', () => {
    const data = buildParticipantUpdateData({
      name: 'Maria Souza',
      email: '',
      cnhCategory: '',
      cnhExpiration: '',
    });

    expect(data).toEqual({
      name: 'Maria Souza',
      email: undefined,
      cnhCategory: undefined,
      cnhExpiration: undefined,
    });
    // As chaves existem (com undefined), como nos objetos `data` que a função substitui.
    expect(Object.keys(data).sort()).toEqual(['cnhCategory', 'cnhExpiration', 'email', 'name']);
  });

  it('tudo preenchido: devolve os valores e a validade como Date', () => {
    expect(
      buildParticipantUpdateData({
        name: 'Maria Souza',
        email: 'maria@empresa.com',
        cnhCategory: 'AB',
        cnhExpiration: '2027-12-31',
      }),
    ).toEqual({
      name: 'Maria Souza',
      email: 'maria@empresa.com',
      cnhCategory: 'AB',
      cnhExpiration: new Date('2027-12-31'),
    });
  });
});
