/* global axios */

// import ApiClient from './ApiClient';

// // class AiAgentLanggraph extends ApiClient {
// //   constructor() {
// //     super('chatflows', {
// //       baseURL: 'https://agent.jangkau.ai', // Ganti dengan base URL yang kamu mau
// //       apiVersion: 'v2',
// //       accountScoped: false,
// //     });
// //   }

// //   getAiAgents() {
// //     return this.get();
// //   }

// //   listAiTemplateLanggraph() {
// //     const fullUrl = `${this.url}?account_id=1&deployed_only=false`;
// //     console.log(fullUrl);
// //     return axios.get(fullUrl);
// //   }
// // }

// // export default new AiAgentLanggraph();
// /* global axios */
// /* global axios */

const DEFAULT_API_VERSION = 'v2';

class AiAgentsLanggraph {
  constructor(options = {}, resource = 'chatflows') {
    this.apiVersion = `/${options.apiVersion || DEFAULT_API_VERSION}`;
    this.options = options;
    this.resource = resource;
    this.account_id = null;
    if (this.options.accountScoped) {
      this.account_id = this.accountIdFromRoute;
    }
  }

  get url() {
    return `${this.baseUrl()}/${this.resource}`;
  }

  // eslint-disable-next-line class-methods-use-this
  get accountIdFromRoute() {
    const isInsideAccountScopedURLs =
      window.location.pathname.includes('/app/accounts');

    if (isInsideAccountScopedURLs) {
      return window.location.pathname.split('/')[3];
    }

    return '';
  }

  baseUrl() {
    let url = this.apiVersion;

    if (this.options.baseUrl) {
      url = `${this.options.baseUrl}${url}`;
    }

    return url;
  }

  chechHealth() {
    return axios.get(`${this.url}/health`, {
      headers: {
        'Accept': 'application/json',
      },
    });
  }

  getAll() {
    console.log('Fetching all agents from:', this.url);
    return axios.get(`${this.url}/`, {
      params: {
        account_id: this.account_id,
        deployed_only: true,
      }
    });
  }

  show(id) {
    return axios.get(`${this.url}/${id}`, {
      headers: {
        'Accept': 'application/json',
      },
    });
  }

  create(data) {
    const payload = {
      ...data,
      account_id: this.account_id,
    };

    return axios.post(`${this.url}/`, payload, {
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, data, {
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new AiAgentsLanggraph({
    baseUrl: 'https://agent.jangkau.ai',
    apiVersion: 'v2',
    accountScoped: true,
});