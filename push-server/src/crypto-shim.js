// Shim for Cloudflare Workers: always use Web Crypto.
const c = globalThis.crypto;
export default c;
export const webcrypto = c;
export const subtle = c.subtle;
export const getRandomValues = c.getRandomValues.bind(c);
