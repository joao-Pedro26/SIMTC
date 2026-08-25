import { redirect } from 'next/navigation';

// Rota raiz redireciona para /login
// O middleware cuidará dos redirecionamentos após login baseados no role
export default function RootPage() {
  redirect('/login');
}
