<template>
  <div v-if="isOpen" class="fixed inset-0 z-[60] flex items-center justify-center p-4 sm:p-6" role="dialog">
    <div class="fixed inset-0 bg-slate-900/50 transition-opacity backdrop-blur-sm" @click="close"></div>

    <div class="relative w-full max-w-3xl max-h-[90vh] overflow-y-auto transform rounded-xl bg-white dark:bg-slate-800 shadow-2xl transition-all flex flex-col border border-gray-200 dark:border-gray-700">
      
      <div class="flex items-center justify-between p-6 border-b border-gray-200 dark:border-gray-700 bg-white dark:bg-slate-800 sticky top-0 z-10">
        <h3 class="text-lg font-bold text-slate-900 dark:text-white">
          {{ isEdit ? $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.EDIT_TITLE') : $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.ADD_TITLE') }}
        </h3>
        <button @click="close" class="text-gray-400 hover:text-gray-500 p-1 rounded-full hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
          <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <div class="p-6 space-y-6">
        
        <div class="grid grid-cols-1 gap-5">
          <div>
            <label class="block text-sm font-medium mb-1.5 text-slate-700 dark:text-slate-300">
              {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.NAME_LABEL') }}
            </label>
            <input 
              v-model="form.name" 
              type="text" 
              :placeholder="$t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.NAME_PLACEHOLDER')"
              class="w-full border border-gray-300 rounded-lg px-3 py-2.5 text-sm focus:ring-2 focus:ring-green-500 focus:border-green-500 dark:bg-slate-900 dark:border-gray-600 dark:text-white transition-all" 
            />
          </div>
          <div>
            <label class="block text-sm font-medium mb-1.5 text-slate-700 dark:text-slate-300">
              {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.ADDRESS_LABEL') }}
            </label>
            <textarea 
              v-model="form.address" 
              rows="2" 
              :placeholder="$t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.ADDRESS_PLACEHOLDER')"
              class="w-full border border-gray-300 rounded-lg px-3 py-2.5 text-sm focus:ring-2 focus:ring-green-500 focus:border-green-500 dark:bg-slate-900 dark:border-gray-600 dark:text-white transition-all"
            ></textarea>
          </div>
        </div>

        <div class="bg-gray-50 dark:bg-slate-900/50 p-4 rounded-xl border border-gray-200 dark:border-gray-700">
          <label class="block text-sm font-medium mb-2 text-slate-700 dark:text-slate-300">
            {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.MAP_LABEL') }}
          </label>
          <div class="relative mb-3 group">
            
            <input 
              id="map-search-input"
              type="text" 
              :placeholder="$t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.MAP_SEARCH_PLACEHOLDER')"
              class="w-full border border-gray-300 rounded-lg pl-10 pr-20 py-2.5 text-sm focus:ring-2 focus:ring-green-500 dark:bg-slate-800 dark:border-gray-600 dark:text-white shadow-sm"
            />
          </div>

          <div class="relative w-full h-[300px] rounded-lg overflow-hidden border border-gray-300 dark:border-gray-600 bg-gray-200">
             <div ref="mapContainer" class="w-full h-full"></div>
             <div v-if="!mapLoaded" class="absolute inset-0 flex flex-col items-center justify-center bg-gray-100 dark:bg-slate-800 z-10">
                <svg class="animate-spin h-8 w-8 text-green-600 mb-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                <span class="text-sm text-gray-500 font-medium">
                  {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.MAP_LOADING') }}
                </span>
             </div>
             <div class="absolute bottom-2 left-2 bg-white/90 dark:bg-slate-900/90 px-2 py-1 rounded text-[10px] text-gray-600 dark:text-gray-300 shadow-sm border border-gray-200 dark:border-gray-700 pointer-events-none">
                {{ form.coordinates.lat?.toFixed(6) }}, {{ form.coordinates.lng?.toFixed(6) }}
             </div>
          </div>
          <p class="text-xs text-gray-500 mt-2">
            <span class="font-medium text-gray-700 dark:text-gray-300">
              {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.MAP_TIPS') }}
            </span> 
            {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.MAP_TIPS_TEXT') }}
          </p>
        </div>

        <div class="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden transition-all duration-300" 
             :class="{'ring-2 ring-green-500/20 border-green-500/50': form.store_courier.enabled}">
          <div class="p-4 flex items-center justify-between bg-white dark:bg-slate-800">
            <div class="flex items-center gap-3">
               <div class="w-10 h-10 rounded-full flex items-center justify-center" 
                    :class="form.store_courier.enabled ? 'bg-green-100 text-green-600' : 'bg-gray-100 text-gray-400 dark:bg-slate-700'">
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
               </div>
               <div>
                  <h4 class="font-semibold text-slate-900 dark:text-white">
                    {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.COURIER_SECTION_TITLE') }}
                  </h4>
                  <p class="text-xs text-gray-500">
                    {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.COURIER_SECTION_DESC') }}
                  </p>
               </div>
            </div>

            <label class="inline-flex items-center cursor-pointer">
                <input type="checkbox" v-model="form.store_courier.enabled" class="sr-only peer">
                <div class="border border-gray-300 w-11 h-6 bg-gray-200 rounded-full peer peer-checked:bg-green-500 relative after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:after:translate-x-full">
                </div>
            </label>
          </div>

          <div v-if="form.store_courier.enabled" class="p-5 border-t border-gray-200 dark:border-gray-700 bg-gray-50/50 dark:bg-slate-900/30 space-y-5 animate-fadeIn">
            <div>
               <label class="block text-xs font-semibold uppercase text-gray-500 mb-2 tracking-wider">
                 {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.OPERATIONAL_HOURS') }}
               </label>
               <div class="grid grid-cols-2 gap-4">
                 <div>
                   <label class="block text-xs text-gray-600 mb-1">
                     {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.OPEN_LABEL') }}
                   </label>
                   <input v-model="form.store_courier.open_time" type="time" class="w-full border border-gray-300 rounded-lg px-2 py-2 text-sm dark:bg-slate-800 dark:border-gray-600" />
                 </div>
                 <div>
                   <label class="block text-xs text-gray-600 mb-1">
                     {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.CLOSE_LABEL') }}
                   </label>
                   <input v-model="form.store_courier.close_time" type="time" class="w-full border border-gray-300 rounded-lg px-2 py-2 text-sm dark:bg-slate-800 dark:border-gray-600" />
                 </div>
               </div>
            </div>

            <div>
              <label class="block text-xs font-semibold uppercase text-gray-500 mb-2 tracking-wider">
                {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.SERVICE_AREA_LABEL') }}
              </label>
              <div class="flex gap-4 mb-3">
                <label class="inline-flex items-center text-sm cursor-pointer">
                  <input type="radio" v-model="form.store_courier.area_type" value="radius" class="text-green-600 focus:ring-green-500 border-gray-300" />
                  <span class="ml-2 text-slate-700 dark:text-slate-300">
                    {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.RADIUS_LABEL') }}
                  </span>
                </label>
                <label class="inline-flex items-center text-sm cursor-pointer">
                  <input type="radio" v-model="form.store_courier.area_type" value="region" class="text-green-600 focus:ring-green-500 border-gray-300"/>
                  <span class="ml-2 text-slate-700 dark:text-slate-300">
                    {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.REGION_LABEL') }}
                  </span>
                </label>
              </div>
              <div v-if="form.store_courier.area_type === 'radius'" class="animate-fadeIn">
                 <div class="relative">
                    <input v-model="form.store_courier.radius" type="number" placeholder="5" class="w-full border border-gray-300 rounded-lg pl-3 pr-10 py-2 text-sm dark:bg-slate-800 dark:border-gray-600" />
                    <span class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-500 text-sm">km</span>
                 </div>
              </div>
              <div v-if="form.store_courier.area_type === 'region'" class="animate-fadeIn mt-3">
  
                <div 
                  v-for="(region, index) in form.store_courier.selected_regions" 
                  :key="index" 
                  class="flex items-start gap-2"
                >
                  <input 
                    v-model="form.store_courier.selected_regions[index]"
                    type="text" 
                    :placeholder="$t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.REGION_PLACEHOLDER')"
                    class="flex-1 w-full border border-gray-300 rounded-lg px-3 py-2 text-sm dark:bg-slate-800 dark:border-gray-600 focus:ring-2 focus:ring-green-500 transition-all" 
                  />
                  
                  <button 
                    @click="removeRegion(index)"
                    type="button"
                    class="self-start p-2 text-gray-400 hover:text-red-500 transition-colors rounded-full hover:bg-gray-100 dark:hover:bg-slate-700"
                    title="Hapus baris ini"
                  >
                    <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>

                <button 
                  @click="addRegion"
                  type="button"
                  class="text-sm text-green-600 hover:text-green-700 font-medium flex items-center gap-1 transition-colors focus:outline-none mt-2"
                >
                  <svg class="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                  </svg>
                  {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.ADD_AREA_BTN') }}
                </button>
              </div>
            </div>

            <div>
              <label class="block text-xs font-semibold uppercase text-gray-500 mb-2 tracking-wider">
                {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.SHIPPING_COST_LABEL') }}
              </label>
              <div class="flex gap-4 mb-3">
                <label class="inline-flex items-center text-sm cursor-pointer">
                  <input type="radio" v-model="form.store_courier.pricing_type" value="flat" class="text-green-600 focus:ring-green-500 border-gray-300" />
                  <span class="ml-2 text-slate-700 dark:text-slate-300">
                    {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.FLAT_RATE_LABEL') }}
                  </span>
                </label>
                <label class="inline-flex items-center text-sm cursor-pointer">
                  <input type="radio" v-model="form.store_courier.pricing_type" value="per_km" class="text-green-600 focus:ring-green-500 border-gray-300" />
                  <span class="ml-2 text-slate-700 dark:text-slate-300">
                    {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.PER_KM_LABEL') }}
                  </span>
                </label>
              </div>
              <div class="relative">
                <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 text-sm font-medium">Rp</span>
                <input v-model="form.store_courier.rate" type="number" class="w-full border border-gray-300 rounded-lg !pl-9 pr-3 py-2 text-sm dark:bg-slate-800 dark:border-gray-600" />
              </div>
            </div>
            
            <div class="bg-white dark:bg-slate-800 p-3 rounded-lg border border-gray-200 dark:border-gray-600">
              <div class="flex items-center justify-between mb-2">
                <span class="text-sm font-medium text-slate-700 dark:text-slate-300">
                  {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.FREE_SHIPPING_LABEL') }}
                </span>
                  
                <label class="inline-flex items-center cursor-pointer">
                   <input type="checkbox" v-model="form.store_courier.free_shipping" class="sr-only peer">
                   <div class="border border-gray-300 w-11 h-6 bg-gray-200 rounded-full peer peer-checked:bg-green-500 relative after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:after:translate-x-full">
                   </div>
                </label>
              </div>
               
              <div v-if="form.store_courier.free_shipping" class="animate-fadeIn">
                <label class="block text-xs text-gray-500 mb-1">
                  {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.MIN_PURCHASE_LABEL') }}
                </label>
                <div class="relative">
                   <span class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-500 text-xs pointer-events-none">Rp</span>
                   <input v-model="form.store_courier.min_purchase" type="number" class="w-full border border-gray-300 rounded px-2 !pl-8 py-1.5 text-sm dark:bg-slate-900 dark:border-gray-600" />
                </div>
              </div>
            </div>

            <div>
               <label class="block text-xs font-semibold uppercase text-gray-500 mb-1 tracking-wider">
                 {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.ESTIMATION_LABEL') }}
               </label>
               <input 
                  v-model="form.store_courier.estimasi" 
                  type="text" 
                  :placeholder="$t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.ESTIMATION_PLACEHOLDER')" 
                  class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm dark:bg-slate-800 dark:border-gray-600" 
               />
            </div>
          </div>
        </div>

        <div class="border border-gray-200 dark:border-gray-700 rounded-xl overflow-hidden transition-all duration-300"
             :class="{'ring-2 ring-green-500/20 border-green-500/50': form.store_pickup.enabled}">
          <div class="p-4 flex items-center justify-between bg-white dark:bg-slate-800">
            <div class="flex items-center gap-3">
               <div class="w-10 h-10 rounded-full flex items-center justify-center" 
                    :class="form.store_pickup.enabled ? 'bg-green-100 text-green-600' : 'bg-gray-100 text-gray-400 dark:bg-slate-700'">
                  <svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                     <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m8-2a2 2 0 11-4 0 2 2 0 014 0z" />
                  </svg>
               </div>
               <div>
                  <h4 class="font-semibold text-slate-900 dark:text-white">
                    {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.PICKUP_SECTION_TITLE') }}
                  </h4>
                  <p class="text-xs text-gray-500">
                    {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.PICKUP_SECTION_DESC') }}
                  </p>
               </div>
            </div>
            
            <label class="inline-flex items-center cursor-pointer">
               <input type="checkbox" v-model="form.store_pickup.enabled" class="sr-only peer">
               <div class="border border-gray-300 w-11 h-6 bg-gray-200 rounded-full peer peer-checked:bg-green-500 relative after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:after:translate-x-full">
               </div>
            </label>
          </div>          
          <div v-if="form.store_pickup.enabled" class="p-5 border-t border-gray-200 dark:border-gray-700 bg-gray-50/50 dark:bg-slate-900/30 space-y-4 animate-fadeIn">
            <div>
               <label class="block text-xs font-semibold uppercase text-gray-500 mb-2 tracking-wider">
                 {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.OPERATIONAL_HOURS') }}
               </label>
               <div class="grid grid-cols-2 gap-4">
                 <div>
                   <label class="block text-xs text-gray-600 mb-1">
                     {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.OPEN_LABEL') }}
                   </label>
                   <input v-model="form.store_pickup.open_time" type="time" class="w-full border border-gray-300 rounded-lg px-2 py-2 text-sm dark:bg-slate-800 dark:border-gray-600" />
                 </div>
                 <div>
                   <label class="block text-xs text-gray-600 mb-1">
                     {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.CLOSE_LABEL') }}
                   </label>
                   <input v-model="form.store_pickup.close_time" type="time" class="w-full border border-gray-300 rounded-lg px-2 py-2 text-sm dark:bg-slate-800 dark:border-gray-600" />
                 </div>
               </div>
            </div>
            <div>
               <label class="block text-xs font-semibold uppercase text-gray-500 mb-1 tracking-wider">
                 {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.ESTIMATION_PICKUP_LABEL') }}
               </label>
               <input 
                 v-model="form.store_pickup.estimasi" 
                 type="text" 
                 :placeholder="$t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.ESTIMATION_PLACEHOLDER')" 
                 class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm dark:bg-slate-800 dark:border-gray-600" 
               />
            </div>
          </div>
        </div>

      </div>

      <div class="p-5 border-t border-gray-200 dark:border-gray-700 flex justify-end gap-3 bg-gray-50 dark:bg-slate-800 sticky bottom-0 z-20">
        <button @click="close" class="px-5 py-2.5 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 hover:bg-white hover:border-gray-400 transition-all dark:border-gray-600 dark:text-gray-200 dark:hover:bg-slate-700">
          {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.CANCEL_BTN') }}
        </button>
        <button @click="save" class="px-5 py-2.5 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700 shadow-sm hover:shadow transition-all transform active:scale-95">
          {{ $t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.SAVE_BTN') }}
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, watch, nextTick, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';

const { t } = useI18n();

const props = defineProps({
  isOpen: Boolean,
  initialData: Object
});

const emit = defineEmits(['close', 'save']);

// State
const mapContainer = ref(null);
const mapLoaded = ref(false);
const mapInstance = ref(null);
const markerInstance = ref(null);

const regionInput = ref('');

const isEdit = ref(false);

const form = reactive({
  id: null,
  name: '',
  address: '',
  coordinates: { lat: -6.2088, lng: 106.8456 },
  store_courier: {
    enabled: false,
    open_time: '08:00',
    close_time: '21:00',
    area_type: 'radius',
    radius: 5,
    selected_regions: [], // Array untuk menyimpan daftar area
    pricing_type: 'flat',
    rate: 5000,
    free_shipping: false,
    min_purchase: 0,
    estimasi: '1 jam setelah pembayaran'
  },
  store_pickup: {
    enabled: false,
    open_time: '08:00',
    close_time: '21:00',
    estimasi: '1 jam setelah pembayaran'
  }
});

// Maps Logic
const GOOGLE_MAPS_API_KEY = window.chatwootConfig?.googleMapsApiKey || '';

const initMap = () => {
  if (!mapContainer.value || !window.google) return;

  // 1. Inisialisasi Geocoder
  const geocoder = new window.google.maps.Geocoder();

  const center = form.coordinates;
  
  // Create Map
  mapInstance.value = new window.google.maps.Map(mapContainer.value, {
    center: center,
    zoom: 15,
    mapTypeControl: false,
    streetViewControl: false,
    fullscreenControl: false,
    zoomControl: true,
  });

  // Create Marker
  markerInstance.value = new window.google.maps.Marker({
    position: center,
    map: mapInstance.value,
    draggable: true,
    animation: window.google.maps.Animation.DROP
  });

  markerInstance.value.addListener('dragend', (e) => {
    const latLng = e.latLng;
    form.coordinates.lat = latLng.lat();
    form.coordinates.lng = latLng.lng();

    geocoder.geocode({ location: latLng }, (results, status) => {
      if (status === 'OK' && results[0]) {
        form.address = results[0].formatted_address;
      } else {
        console.warn('Geocoder failed due to: ' + status);
      }
    });
  });

  // Setup Search Box
  const input = document.getElementById('map-search-input');
  if (input) {
    const searchBox = new window.google.maps.places.SearchBox(input);

    searchBox.addListener('places_changed', () => {
      const places = searchBox.getPlaces();
      if (places.length == 0) return;

      const place = places[0];
      if (!place.geometry || !place.geometry.location) return;

      if (place.geometry.viewport) {
        mapInstance.value.fitBounds(place.geometry.viewport);
      } else {
        mapInstance.value.setCenter(place.geometry.location);
        mapInstance.value.setZoom(17);
      }

      markerInstance.value.setPosition(place.geometry.location);
      form.coordinates.lat = place.geometry.location.lat();
      form.coordinates.lng = place.geometry.location.lng();

      if (place.formatted_address) {
        form.address = place.formatted_address;
      }
    });
  }
  
  mapLoaded.value = true;
};

const loadGoogleMaps = () => {
  if (window.google && window.google.maps) {
    initMap();
    return;
  }

  if (!document.querySelector('script[src*="maps.googleapis.com"]')) {
     const script = document.createElement('script');
     script.src = `https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_API_KEY}&libraries=places`;
     script.async = true;
     script.defer = true;
     script.onload = initMap;
     document.head.appendChild(script);
  } else {
     const checkGoogle = setInterval(() => {
        if (window.google && window.google.maps) {
           clearInterval(checkGoogle);
           initMap();
        }
     }, 200);
  }
};

// Fungsi Tambah Region
const addRegion = () => {
  if (!form.store_courier.selected_regions) {
    form.store_courier.selected_regions = [];
  }
  
  // Push string kosong untuk memunculkan input baru
  form.store_courier.selected_regions.push('');
};

// Fungsi Hapus Region
const removeRegion = (index) => {
  if (form.store_courier.selected_regions) {
    form.store_courier.selected_regions.splice(index, 1);
  }
};

watch(() => form.store_courier.area_type, (newVal) => {
  if (newVal === 'region') {
    // Jika array belum ada atau kosong, isi dengan satu string kosong
    if (!form.store_courier.selected_regions || form.store_courier.selected_regions.length === 0) {
      form.store_courier.selected_regions = [''];
    }
  }
});

watch(() => props.isOpen, (newVal) => {
  if (newVal) {
    if (props.initialData) {
      // MODE EDIT
      isEdit.value = true;
      const data = JSON.parse(JSON.stringify(props.initialData));
      Object.assign(form, data);
      
      // Default values check
      if (!form.coordinates) form.coordinates = { lat: -6.2088, lng: 106.8456 };
      if (!form.store_courier) form.store_courier = { enabled: false };
      if (!form.store_pickup) form.store_pickup = { enabled: false };
      
      // Pastikan array selected_regions ada saat edit
      if (!form.store_courier.selected_regions) {
        form.store_courier.selected_regions = [];
      }

    } else {
      // MODE TAMBAH BARU (RESET FORM)
      isEdit.value = false;
      form.id = null; 
      form.name = '';
      form.address = '';
      form.coordinates = { lat: -6.2088, lng: 106.8456 }; 
      
      form.store_courier = {
        enabled: false,
        open_time: '08:00',
        close_time: '21:00',
        area_type: 'radius',
        radius: 5,
        selected_regions: [], // Reset kosong
        pricing_type: 'flat',
        rate: 5000,
        free_shipping: false,
        min_purchase: 0,
        estimasi: '1 jam setelah pembayaran'
      };
      
      form.store_pickup = {
        enabled: false,
        open_time: '08:00',
        close_time: '21:00',
        estimasi: '1 jam setelah pembayaran'
      };
    }

    // Reset map loading state
    mapLoaded.value = false;
    regionInput.value = ''; // Reset input text region
    
    nextTick(() => {
      loadGoogleMaps();
    });
  }
});

const close = () => {
  emit('close');
};

const save = () => {
  if (!form.name || !form.address) {
    alert(t('AGENT_MGMT.SALESBOT.SHIPPING.MODAL.VALIDATION_ALERT'));
    return;
  }
  emit('save', JSON.parse(JSON.stringify(form)));
  close();
};
</script>

<style scoped>
.animate-fadeIn {
  animation: fadeIn 0.3s ease-out;
}
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(-5px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>