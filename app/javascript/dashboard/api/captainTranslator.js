/* global axios */

import ApiClient from './ApiClient';

class CaptainTranslator extends ApiClient {
  constructor() {
    super('', { accountScoped: true });
  }

  translateJson(jsonData, targetLanguage = 'en') {
    return axios.post(`${this.url}/translate`, {
      json_data: jsonData,
      target_language: targetLanguage,
    });
  }
}

export default new CaptainTranslator();
