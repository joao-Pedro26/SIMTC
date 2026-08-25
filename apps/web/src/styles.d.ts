// Permite importar arquivos CSS globais como side-effect (ex: import './globals.css')
// O Next.js processa estes imports via webpack; o TypeScript só precisa saber que
// o módulo existe para não rejeitar a importação.
declare module '*.css' {}
