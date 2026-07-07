let testNow: Date | null = null;

export function now(): Date {
  return testNow ?? new Date();
}

export function todayUtc(date = now()): string {
  return date.toISOString().slice(0, 10);
}

export function setNowForTests(value: string | null): void {
  testNow = value == null ? null : new Date(value);
}

export function daysBetweenUtcDates(fromDate: string, toDate: string): number {
  const fromMs = Date.parse(`${fromDate}T00:00:00.000Z`);
  const toMs = Date.parse(`${toDate}T00:00:00.000Z`);
  if (!Number.isFinite(fromMs) || !Number.isFinite(toMs)) {
    return 0;
  }
  return Math.floor((toMs - fromMs) / 86_400_000);
}
