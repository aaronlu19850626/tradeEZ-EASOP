import { Action, Shell } from "@/components/tradeez";
export default function NotFound() { return <Shell><section className="container section missing-page"><span className="chapter mono">404 / PAGE NOT FOUND</span><h1>这里暂时没有页面。</h1><p>返回产品总览，继续了解 TradeEZ。</p><Action href="/">回到首页</Action></section></Shell>; }
