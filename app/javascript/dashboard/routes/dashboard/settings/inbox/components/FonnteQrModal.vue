<template>
  <div class="p-4">
    <h2 class="text-lg font-semibold text-center">Scan QR Code to Activate WhatsApp</h2>
    <img :src="qrCode" alt="QR Code" class="max-w-xs mx-auto mt-4 border border-gray-200" />
    <p class="mt-4 text-sm text-center text-gray-600">
      Open WhatsApp → Linked Devices → Scan this QR Code
    </p>
    <div class="text-center mt-4">
      <woot-button color-scheme="success" @click="confirmScan">
        I’ve Scanned
      </woot-button>
    </div>
  </div>
</template>

<script>
export default {
  props: {
    qrCode: {
      type: String,
      required: true,
    },
    onActivated: {
      type: Function,
      required: true,
    },
  },
  methods: {
    confirmScan() {
      this.onActivated();
      this.$emit('close');
    },
  },
};
</script>
