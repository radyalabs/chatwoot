/* global axios */
import ApiClient from './ApiClient';

class ContactAttributeKeysAPI extends ApiClient {
  constructor() {
    super('contact_attribute_keys', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(key, dataType = 'text') {
    return axios.post(this.url, { key, data_type: dataType });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new ContactAttributeKeysAPI();
