import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "TWL Pipeline - Data Management",
  description: "Real-time data ingestion and processing pipeline",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body className="antialiased">
        <nav className="bg-blue-600 text-white shadow-lg">
          <div className="container mx-auto px-4 py-4">
            <div className="flex items-center justify-between">
              <a href="/" className="text-2xl font-bold">TWL Pipeline</a>
              <div className="space-x-4">
                <a href="/" className="hover:underline">Dashboard</a>
                <a href="/records" className="hover:underline">Records</a>
              </div>
            </div>
          </div>
        </nav>
        <main className="container mx-auto px-4 py-8">
          {children}
        </main>
      </body>
    </html>
  );
}

