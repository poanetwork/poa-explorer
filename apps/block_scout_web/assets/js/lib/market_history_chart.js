import $ from 'jquery'
import Chart from 'chart.js'
import humps from 'humps'
import numeral from 'numeral'
import { formatUsdValue } from '../lib/currency'
import sassVariables from '../../css/app.scss'
import { showLoader } from '../lib/utils'

const config = {
  type: 'line',
  responsive: true,
  data: {
    datasets: []
  },
  options: {
    legend: {
      display: false
    },
    scales: {
      xAxes: [{
        gridLines: {
          display: false,
          drawBorder: false
        },
        type: 'time',
        time: {
          unit: 'day',
          stepSize: 14
        },
        ticks: {
          fontColor: sassVariables.dashboardBannerChartAxisFontColor
        }
      }],
      yAxes: [{
        id: 'price',
        gridLines: {
          display: false,
          drawBorder: false
        },
        ticks: {
          beginAtZero: true,
          callback: (value, index, values) => `$${numeral(value).format('0,0.00')}`,
          maxTicksLimit: 4,
          fontColor: sassVariables.dashboardBannerChartAxisFontColor
        }
      }, {
        id: 'marketCap',
        position: 'right',
        gridLines: {
          display: false,
          drawBorder: false
        },
        ticks: {
          callback: (value, index, values) => '',
          maxTicksLimit: 6,
          drawOnChartArea: false
        }
      }]
    },
    tooltips: {
      mode: 'index',
      intersect: false,
      callbacks: {
        label: ({datasetIndex, yLabel}, {datasets}) => {
          const label = datasets[datasetIndex].label
          if (datasets[datasetIndex].yAxisID === 'price') {
            return `${label}: ${formatUsdValue(yLabel)}`
          } else if (datasets[datasetIndex].yAxisID === 'marketCap') {
            return `${label}: ${formatUsdValue(yLabel)}`
          } else {
            return yLabel
          }
        }
      }
    }
  }
}
function getPriceData (marketHistoryData) {
  return marketHistoryData.map(({ date, closingPrice }) => ({x: date, y: closingPrice}))
}

function getRetrievedPriceData (retrievedMarket) {
  retrievedMarket = JSON.parse(localStorage.getItem('marketStorage'))
  return retrievedMarket.map(({ date, closingPrice }) => ({x: date, y: closingPrice}))
}

function getRetrievedMarketData (retrievedMarket, retrievedSupply) {
  retrievedSupply = JSON.parse(localStorage.getItem('supplyStorage'))
  retrievedMarket = JSON.parse(localStorage.getItem('marketStorage'))
  if (retrievedSupply !== null && typeof retrievedSupply === 'object') {
    return retrievedMarket.map(({ date, closingPrice }) => ({x: date, y: closingPrice * retrievedSupply[date]}))
  } else {
    return retrievedMarket.map(({ date, closingPrice }) => ({x: date, y: closingPrice * retrievedSupply}))
  }
}

// colors for light and dark theme
var priceLineColor
var mcapLineColor
if (localStorage.getItem('current-color-mode') === 'dark') {
  priceLineColor = sassVariables.darkprimary
  mcapLineColor = sassVariables.darksecondary
} else {
  priceLineColor = sassVariables.dashboardLineColorPrice
  mcapLineColor = sassVariables.dashboardLineColorMarket
}

class MarketHistoryChart {
  constructor (el, retrievedSupply, retrievedMarket) {
    this.price = {
      label: window.localized['Price'],
      yAxisID: 'price',
      data: getRetrievedPriceData(retrievedMarket),
      fill: false,
      pointRadius: 0,
      backgroundColor: priceLineColor,
      borderColor: priceLineColor,
      lineTension: 0
    }
    this.marketCap = {
      label: window.localized['Market Cap'],
      yAxisID: 'marketCap',
      data: getRetrievedMarketData(retrievedMarket, retrievedSupply),
      fill: false,
      pointRadius: 0,
      backgroundColor: mcapLineColor,
      borderColor: mcapLineColor,
      lineTension: 0
    }
    this.retrievedSupply = retrievedSupply
    config.data.datasets = [this.price, this.marketCap]
    this.chart = new Chart(el, config)
  }
  update (availableSupply, marketHistoryData) {
    this.price.data = getPriceData(marketHistoryData)
    if (this.availableSupply !== null && typeof this.availableSupply === 'object') {
      const today = new Date().toJSON().slice(0, 10)
      this.availableSupply[today] = availableSupply
      var retrievedSupply = JSON.parse(localStorage.getItem('supplyStorage'))
      var retrievedMarket = JSON.parse(localStorage.getItem('marketStorage'))
      this.marketCap.data = getRetrievedMarketData(retrievedMarket, this.retrievedSupply)
    } else {
      this.marketCap.data = getRetrievedMarketData(retrievedMarket, retrievedSupply)
    }
    this.chart.update()
  }
}

export function createMarketHistoryChart (el) {
  const dataPath = el.dataset.market_history_chart_path
  const $chartLoading = $('[data-chart-loading-message]')

  const isTimeout = true
  const timeoutID = showLoader(isTimeout, $chartLoading)

  const $chartError = $('[data-chart-error-message]')
  const chart = new MarketHistoryChart(el, 0, [])
  $.getJSON(dataPath, {type: 'JSON'})
    .done(data => {
      const availableSupply = JSON.parse(data.supply_data)
      const marketHistoryData = humps.camelizeKeys(JSON.parse(data.history_data))
      localStorage.setItem('supplyStorage', JSON.stringify(availableSupply))
      localStorage.setItem('marketStorage', JSON.stringify(marketHistoryData))
      var retrievedSupply = JSON.parse(localStorage.getItem('supplyStorage'))
      var retrievedMarket = JSON.parse(localStorage.getItem('marketStorage'))
      $(el).show()
      chart.update(retrievedSupply, retrievedMarket)
    })
    .fail(() => {
      $chartError.show()
    })
    .always(() => {
      $chartLoading.hide()
      clearTimeout(timeoutID)
    })
  return chart
}

$('[data-chart-error-message]').on('click', _event => {
  $('[data-chart-loading-message]').show()
  $('[data-chart-error-message]').hide()
  createMarketHistoryChart($('[data-chart="marketHistoryChart"]')[0])
})
