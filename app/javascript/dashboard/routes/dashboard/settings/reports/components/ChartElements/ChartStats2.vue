<script setup>
defineProps({
  title: {
    type: String,
  },
  desc: {
    type: String,
  },
  legend1: {
    type: String,
  },
  legend2: {
    type: String,
  },
})
</script>

<template>
  <div class="text-n-slate-11">
    <span class="text-sm">
      {{ title }}
    </span>
    <div class="flex items-center text-n-slate-12 mt-1">
      <div class="text-xl font-medium flex-1">
        {{ desc }}
      </div>
      <div class="flex flex-wrap justify-end gap-3 flex-end">
        <div class="text-sm flex flex-row gap-1 items-center">
          <div class="rounded-full h-2 w-2 circle2"></div>
          <span>{{ $t(legend1) }}</span>
        </div>
        <div class="text-sm flex flex-row gap-1 items-center">
          <div class="rounded-full h-2 w-2 circle1"></div>
          <span>{{ $t(legend2) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style>
.circle1 {
  background-color: rgb(31, 147, 255);
}
.circle2 {
  background-color: rgb(144, 196, 245);
}
</style>