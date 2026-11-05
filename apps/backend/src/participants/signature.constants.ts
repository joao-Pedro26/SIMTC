/** Bucket privado do Supabase Storage onde ficam as assinaturas (também usado pelos consultores). */
export const SIGNATURE_BUCKET = 'signatures';

/** Tamanho máximo do arquivo de assinatura enviado pelo formulário público. */
export const SIGNATURE_MAX_BYTES = 300 * 1024;

/** Limite por IP das rotas de assinatura que conferem CPF + e-mail (prévia e remoção). */
export const SIGNATURE_LOOKUP_THROTTLE = { default: { limit: 20, ttl: 3600_000 } };
