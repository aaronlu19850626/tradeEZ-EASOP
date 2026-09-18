import type { Metadata } from "next";
import "./site.css";

export const metadata: Metadata = {
  title: { default: "TradeEZ｜让每一笔交易有计划、有纪律、有复盘", template: "%s · TradeEZ" },
  description: "TradeEZ MT5 EA 与交易复盘平台：分策略持仓管理、风险限制、交易日志、规则检查与每日复盘。平台首版筹备中。",
  icons: {
    icon: "/favicon.png",
    shortcut: "/favicon.png",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN" className="dark">
      <body className="antialiased">{children}</body>
    </html>
  );
}
