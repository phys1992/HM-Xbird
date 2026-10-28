export class WebTheme {
  static background(dark: boolean): string {
    return dark ? '#000000' : '#FFFFFF';
  }

  static foreground(dark: boolean): string {
    return dark ? '#E7E9EA' : '#0F1419';
  }

  static script(dark: boolean): string {
    const accent = '#1D9BF0';
    const muted = dark ? '#71767B' : '#536471';
    const colorScheme = dark ? 'dark' : 'light';
    const css = [
      `:root{color-scheme:${colorScheme};--hm-accent:${accent};--hm-muted:${muted};}`,
      `button,[role="button"]{border-radius:14px!important;}`,
      `input,textarea{border-radius:14px!important;}`,
      `a{color:${accent}!important;}`
    ].join('');
    return `(function(){try{var id='hm-web-theme';var old=document.getElementById(id);if(old)old.remove();var s=document.createElement('style');s.id=id;s.textContent=${JSON.stringify(css)};(document.head||document.documentElement).appendChild(s);document.documentElement.style.colorScheme='${colorScheme}';}catch(e){}})();`;
  }
}
