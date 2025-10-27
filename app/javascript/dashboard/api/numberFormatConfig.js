/* global axios */

import ApiClient from './ApiClient';

class NumberFormatConfigAPI extends ApiClient {
  constructor() {
    super('number_format_config', { accountScoped: true });
  }

  getConfig() {
    return axios.get(this.url);
  }

  createConfig(data) {
    const requestData = {
      number_format_config: data,
    };
    return axios.post(this.url, requestData);
  }

  updateConfig(data) {
    const requestData = {
      number_format_config: data,
    };
    return axios.put(this.url, requestData);
  }
}

export default new NumberFormatConfigAPI();