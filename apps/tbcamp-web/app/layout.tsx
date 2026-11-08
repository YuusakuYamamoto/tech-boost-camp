import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'tech-boost-camp',
};

export default function RootLayout({ children }: LayoutProps<'/'>) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
