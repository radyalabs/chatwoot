/* global axios */

import ApiClient from './ApiClient';

class CaptainTranslator extends ApiClient {
  constructor() {
    super('', { accountScoped: true });
  }

  translate(text, targetLanguage = 'en') {
    return axios.post(`${this.url}/translate`, {
      text,
      target_language: targetLanguage,
    });
  }
}

export default new CaptainTranslator();
