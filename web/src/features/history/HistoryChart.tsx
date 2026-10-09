import { LineChart } from 'echarts/charts';
import { AriaComponent, DataZoomComponent, GridComponent, LegendComponent, TooltipComponent } from 'echarts/components';
import * as echarts from 'echarts/core';
import { SVGRenderer } from 'echarts/renderers';
import { useEffect, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import type { Series } from '../../api/types';
import { formatNumber } from '../../i18n/format';
import { seriesLabel } from './HistoryTable';

// Interactive history chart (FR-008, research R2): loaded only by the history screen (React.lazy), with
// the modules it needs. Colours come from the theme tokens, times are shown in the browser's zone, the
// ECharts ARIA description is on, and motion follows "reduce motion".

echarts.use([LineChart, GridComponent, TooltipComponent, LegendComponent, DataZoomComponent, AriaComponent, SVGRenderer]);

function token(name: string): string {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}

export default function HistoryChart({ series, label, unit }: { series: Series[]; label: string; unit?: string }) {
  const { t, i18n } = useTranslation();
  const ref = useRef<HTMLDivElement>(null);
  const chart = useRef<echarts.ECharts | null>(null);
  const lang = i18n.language;

  useEffect(() => {
    if (!ref.current) return;
    chart.current = echarts.init(ref.current, undefined, { renderer: 'svg' });
    const observer = new ResizeObserver(() => chart.current?.resize());
    observer.observe(ref.current);
    return () => {
      observer.disconnect();
      chart.current?.dispose();
      chart.current = null;
    };
  }, []);

  useEffect(() => {
    const draw = () => {
      const reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;
      const colors = [1, 2, 3, 4, 5, 6].map((i) => token(`--color-series-${i}`));
      const text = token('--color-text');
      const muted = token('--color-muted');
      const divider = token('--color-divider');
      const time = new Intl.DateTimeFormat(lang, { dateStyle: 'medium', timeStyle: 'short' });
      const axisTime = new Intl.DateTimeFormat(lang, { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
      chart.current?.setOption(
        {
          animation: !reduce,
          color: colors,
          aria: { enabled: true, label: { description: label } },
          textStyle: { fontFamily: 'Inter Variable, ui-sans-serif, system-ui, sans-serif', color: text },
          grid: { left: 8, right: 16, top: 36, bottom: 56, containLabel: true },
          legend: { top: 0, textStyle: { color: text } },
          tooltip: {
            trigger: 'axis',
            backgroundColor: token('--color-raised'),
            borderColor: divider,
            textStyle: { color: text },
            valueFormatter: (v: unknown) => (typeof v === 'number' ? `${formatNumber(v, lang)}${unit ? ` ${unit}` : ''}` : ''),
            axisPointer: { label: { formatter: (p: { value: unknown }) => time.format(new Date(Number(p.value))) } },
          },
          xAxis: {
            type: 'time',
            axisLabel: { color: muted, hideOverlap: true, formatter: (v: number) => axisTime.format(new Date(v)) },
            axisLine: { lineStyle: { color: divider } },
          },
          yAxis: {
            type: 'value',
            scale: true,
            axisLabel: { color: muted, formatter: (v: number) => formatNumber(v, lang) },
            splitLine: { lineStyle: { color: divider } },
          },
          dataZoom: [
            { type: 'inside' },
            { type: 'slider', height: 22, bottom: 8, borderColor: divider, textStyle: { color: muted } },
          ],
          series: series.map((s) => ({
            name: seriesLabel(s.name, t),
            type: 'line',
            showSymbol: s.points.length < 60,
            symbolSize: 5,
            sampling: 'lttb',
            areaStyle: series.length === 1 ? { opacity: 0.1 } : undefined,
            data: s.points.map((p) => [p.t, p.v]),
          })),
        },
        { notMerge: true },
      );
    };
    draw();
    // Redraw when the appearance changes (applyTheme sets data-theme on <html>).
    const themeWatch = new MutationObserver(draw);
    themeWatch.observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
    return () => themeWatch.disconnect();
  }, [series, label, unit, lang, t]);

  return <div ref={ref} data-chart="" className="h-[360px] w-full max-sm:h-[280px]" />;
}
