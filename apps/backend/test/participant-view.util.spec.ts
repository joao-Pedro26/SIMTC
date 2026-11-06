import { toPublicParticipant, withPublicParticipant } from 'src/participants/participant-view.util';

describe('participant-view.util', () => {
  const base = { id: 'p1', name: 'Maria', cpf: '123', email: null };

  it('toPublicParticipant remove signaturePath/signatureUpdatedAt e marca hasSignature true', () => {
    const out = toPublicParticipant({
      ...base,
      signaturePath: 'participants/p1/sig.png',
      signatureUpdatedAt: new Date(),
    });
    expect(out).toEqual({ ...base, hasSignature: true });
    expect(out).not.toHaveProperty('signaturePath');
    expect(out).not.toHaveProperty('signatureUpdatedAt');
  });

  it('toPublicParticipant devolve hasSignature false sem assinatura', () => {
    expect(toPublicParticipant({ ...base, signaturePath: null, signatureUpdatedAt: null })).toEqual({
      ...base,
      hasSignature: false,
    });
    expect(toPublicParticipant({ ...base, signaturePath: undefined })).toEqual({ ...base, hasSignature: false });
  });

  it('withPublicParticipant preserva os demais campos do registro', () => {
    const out = withPublicParticipant({
      id: 'tp1',
      status: 'PENDENTE',
      assessment: null,
      participant: { ...base, signaturePath: 'x.png', signatureUpdatedAt: new Date() },
    });
    expect(out).toEqual({
      id: 'tp1',
      status: 'PENDENTE',
      assessment: null,
      participant: { ...base, hasSignature: true },
    });
  });
});
