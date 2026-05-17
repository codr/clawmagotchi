import type { Metadata } from "next";
import { EmotionRegistry } from "@/lib/emotion-registry";

export const metadata: Metadata = {
  title: "Clawmagotchi",
  description: "A claw machine tamagotchi game",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <EmotionRegistry>{children}</EmotionRegistry>
      </body>
    </html>
  );
}
