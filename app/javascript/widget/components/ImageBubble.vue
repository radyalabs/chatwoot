<script>
export default {
  props: {
    url: { type: String, default: '' },
    thumb: { type: String, default: '' },
    readableTime: { type: String, default: '' },
    hideTime: { type: Boolean, default: false },
    fullWidth: { type: Boolean, default: false },
  },
  emits: ['error'],
  methods: {
    onImgError() {
      this.$emit('error');
    },
  },
};
</script>

<template>
  <a
    :href="url"
    target="_blank"
    rel="noreferrer noopener nofollow"
    class="image"
    :class="{ 'full-width': fullWidth }"
  >
    <div class="wrap">
      <img :src="thumb" alt="Picture message" @error="onImgError" />
      <span v-if="!hideTime" class="time">{{ readableTime }}</span>
    </div>
  </a>
</template>

<style lang="scss" scoped>
@import 'widget/assets/scss/variables.scss';

.image {
  display: block;

  .wrap {
    position: relative;
    display: flex;
    max-width: 100%;

    &::before {
      background-image: linear-gradient(
        -180deg,
        transparent 3%,
        $color-heading 130%
      );
      bottom: 0;
      content: '';
      height: 20%;
      left: 0;
      opacity: 0.8;
      position: absolute;
      width: 100%;
    }
  }

  img {
    width: 100%;
    max-width: 250px;
  }

  .time {
    font-size: $font-size-small;
    bottom: $space-smaller;
    color: $color-white;
    position: absolute;
    right: $space-slab;
    white-space: nowrap;
  }

  // Full-width variant for combined messages
  &.full-width {
    width: 100%;

    .wrap {
      width: 100%;
      max-width: 100%;
    }

    img {
      max-width: 100%;
      width: 100%;
      object-fit: cover;
    }

    // Hide the gradient overlay for full-width images
    .wrap::before {
      display: none;
    }
  }
}
</style>