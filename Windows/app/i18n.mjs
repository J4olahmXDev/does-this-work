export function translator(catalog, language) {
  const lookup = key => typeof key === 'string' && language === 'th' ? (catalog[key] ?? key) : String(key);
  return (key, ...values) => {
    const text = lookup(key);
    if (!values.length) return text;
    let next = 0;
    return text.replace(/%(?:(\d+)\$)?@/g, (_, position) => lookup(values[position ? Number(position) - 1 : next++] ?? ''));
  };
}
