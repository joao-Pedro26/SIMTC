/** Bucket privado do Supabase Storage onde ficam as assinaturas (também usado pelos consultores). */
export const SIGNATURE_BUCKET = 'signatures';

/** Tamanho máximo do arquivo de assinatura enviado pelo formulário público. */
export const SIGNATURE_MAX_BYTES = 300 * 1024;

/*
 * Limites por IP. Uma turma no mesmo Wi-Fi compartilha o IP, por isso os limites
 * da inscrição e da prévia são folgados; a remoção (ação rara) fica mais apertada.
 */

/** Limite por hora da prévia da assinatura (CPF + e-mail que conferem). */
export const SIGNATURE_PREVIEW_THROTTLE = { default: { limit: 100, ttl: 3600_000 } };

/** Limite por hora da remoção da própria assinatura (CPF + e-mail que conferem). */
export const SIGNATURE_REMOVE_THROTTLE = { default: { limit: 20, ttl: 3600_000 } };
