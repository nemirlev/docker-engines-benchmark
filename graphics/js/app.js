// Получаем компоненты из глобального Recharts
const {
    BarChart,
    Bar,
    XAxis,
    YAxis,
    CartesianGrid,
    Tooltip,
    Legend,
    ResponsiveContainer
} = window.Recharts;

const {useState, useEffect} = React;

// Компонент для отображения времени запуска
function StartupPerformance({data}) {
    const [viewMode, setViewMode] = useState('combined');

    const chartData = data.map(item => ({
        name: item.engine,
        min: item.results.min,
        max: item.results.max,
        average: item.results.average
    }));

    const renderCombinedChart = () => (
        <div style={{width: '100%', height: 400}}>
            <ResponsiveContainer>
                <BarChart data={chartData} margin={{top: 20, right: 30, left: 20, bottom: 5}}>
                    <CartesianGrid strokeDasharray="3 3"/>
                    <XAxis dataKey="name"/>
                    <YAxis label={{value: 'Time (seconds)', angle: -90, position: 'insideLeft'}}/>
                    <Tooltip/>
                    <Legend/>
                    <Bar dataKey="min" fill="#4CAF50" name="Minimum Time"/>
                    <Bar dataKey="average" fill="#2196F3" name="Average Time"/>
                    <Bar dataKey="max" fill="#F44336" name="Maximum Time"/>
                </BarChart>
            </ResponsiveContainer>
        </div>
    );

    const renderSeparateCharts = () => (
        <div className="space-y-6">
            {['min', 'average', 'max'].map((metric) => (
                <div key={metric} className="bg-white p-4 rounded-lg shadow">
                    <h2 className="text-lg font-semibold mb-4 capitalize">
                        {metric} Startup Time
                    </h2>
                    <div style={{width: '100%', height: 200}}>
                        <ResponsiveContainer>
                            <BarChart data={chartData}>
                                <CartesianGrid strokeDasharray="3 3"/>
                                <XAxis dataKey="name"/>
                                <YAxis label={{value: 'Time (seconds)', angle: -90, position: 'insideLeft'}}/>
                                <Tooltip/>
                                <Bar
                                    dataKey={metric}
                                    fill={metric === 'min' ? '#4CAF50' : metric === 'average' ? '#2196F3' : '#F44336'}
                                />
                            </BarChart>
                        </ResponsiveContainer>
                    </div>
                </div>
            ))}
        </div>
    );

    return (
        <div className="bg-white rounded-lg shadow-lg p-6 mb-6">
            <div className="flex justify-between items-center mb-6">
                <h2 className="text-xl font-bold">Startup Performance</h2>
                <select
                    className="px-4 py-2 border rounded-lg"
                    value={viewMode}
                    onChange={(e) => setViewMode(e.target.value)}
                >
                    <option value="combined">Combined View</option>
                    <option value="separate">Separate Charts</option>
                </select>
            </div>
            {viewMode === 'combined' ? renderCombinedChart() : renderSeparateCharts()}
        </div>
    );
}

// Компонент для отображения времени сборки
function BuildPerformance({data}) {
    const [selectedTest, setSelectedTest] = useState('all');

    // Функция для получения уникальных типов тестов из всех движков
    const getTestTypes = () => {
        const types = new Set();
        Object.values(data).forEach(engineData => {
            engineData.forEach(build => {
                types.add(build.test_type);
            });
        });
        return Array.from(types).sort();
    };

    // Подготовка данных для графика
    const prepareChartData = () => {
        if (selectedTest === 'all') {
            // Для всех тестов - группируем по типу теста
            const testTypes = getTestTypes();
            return testTypes.map(testType => {
                const dataPoint = {name: testType};

                // Добавляем время для каждого движка
                Object.entries(data).forEach(([engine, builds]) => {
                    const build = builds.find(b => b.test_type === testType);
                    if (build) {
                        dataPoint[engine] = build.build_time;
                    }
                });

                return dataPoint;
            });
        } else {
            // Для конкретного теста - показываем результаты по движкам
            const chartData = [{
                name: selectedTest,
            }];

            Object.entries(data).forEach(([engine, builds]) => {
                const build = builds.find(b => b.test_type === selectedTest);
                if (build) {
                    chartData[0][engine] = build.build_time;
                }
            });

            return chartData;
        }
    };

    // Получаем список движков для создания баров
    const engines = Object.keys(data);
    const testTypes = getTestTypes();
    const chartData = prepareChartData();

    // Генерируем цвета для движков
    const colors = {
        'colima': '#4CAF50',
        'docker-desktop': '#2196F3',
        'podman-desktop': '#F44336',
        'rancher-desktop': '#FF9800',
        'orbstack': '#9C27B0'
    };

    return (
        <div className="bg-white rounded-lg shadow-lg p-6">
            <div className="flex justify-between items-center mb-6">
                <h2 className="text-xl font-bold">Build Performance</h2>
                <select
                    className="px-4 py-2 border rounded-lg"
                    value={selectedTest}
                    onChange={(e) => setSelectedTest(e.target.value)}
                >
                    <option value="all">All Tests</option>
                    {testTypes.map(type => (
                        <option key={type} value={type}>{type}</option>
                    ))}
                </select>
            </div>

            <div style={{width: '100%', height: 400}}>
                <ResponsiveContainer>
                    <BarChart
                        data={chartData}
                        margin={{top: 20, right: 30, left: 50, bottom: 5}}
                    >
                        <CartesianGrid strokeDasharray="3 3"/>
                        <XAxis
                            dataKey="name"
                            label={{
                                value: selectedTest === 'all' ? 'Test Type' : 'Engines',
                                position: 'insideBottom',
                                offset: -5
                            }}
                        />
                        <YAxis
                            label={{
                                value: 'Build Time (seconds)',
                                angle: -90,
                                position: 'insideLeft',
                                offset: -5
                            }}
                        />
                        <Tooltip/>
                        <Legend/>
                        {engines.map(engine => (
                            <Bar
                                key={engine}
                                dataKey={engine}
                                name={engine}
                                fill={colors[engine] || '#8884d8'}
                            />
                        ))}
                    </BarChart>
                </ResponsiveContainer>
            </div>
        </div>
    );
}

// Компонент для отображения метрик производительности
function PerformanceMetrics({ data }) {
    const engines = Object.keys(data.idle || {});

    const getMetricValue = (state, engine, metricKey) => {
        if (data[state] &&
            data[state][engine] &&
            data[state][engine][metricKey] !== undefined) {
            return data[state][engine][metricKey];
        }
        return 0;
    };

    const prepareChartData = (metricKey, metricName, unit) => {
        return engines.map(engine => ({
            name: engine,
            idle: getMetricValue('idle', engine, metricKey),
            load: getMetricValue('load', engine, metricKey),
            unit: unit
        }));
    };

    const metrics = [
        {
            key: 'cpu_average',
            name: 'CPU Usage',
            unit: '%',
            color: { idle: '#4CAF50', load: '#F44336' }
        },
        {
            key: 'memory_average',
            name: 'Memory Usage',
            unit: 'MB',
            color: { idle: '#2196F3', load: '#FF9800' }
        },
        {
            key: 'power_average_mw',
            name: 'Power Consumption',
            unit: 'mW',
            color: { idle: '#9C27B0', load: '#E91E63' }
        }
    ];

    const MetricChart = ({ metric }) => {
        const chartData = prepareChartData(metric.key, metric.name, metric.unit);

        const CustomTooltip = ({ active, payload, label }) => {
            if (active && payload && payload.length) {
                return (
                    <div className="bg-white p-3 border border-gray-200 shadow-lg rounded">
                        <p className="font-semibold">{label}</p>
                        {payload.map((item, index) => (
                            <p key={index} style={{ color: item.color }}>
                                {item.dataKey === 'idle' ? 'Idle State: ' : 'Under Load: '}
                                {item.value.toFixed(2)} {chartData[0].unit}
                            </p>
                        ))}
                    </div>
                );
            }
            return null;
        };

        return (
            <div className="bg-white rounded-lg shadow p-4 mb-6">
                <h3 className="text-lg font-semibold mb-4">{metric.name}</h3>
                <div style={{ width: '100%', height: 300 }}>
                    <ResponsiveContainer>
                        <BarChart
                            data={chartData}
                            margin={{ top: 20, right: 30, left: 50, bottom: 5 }}
                        >
                            <CartesianGrid strokeDasharray="3 3" />
                            <XAxis dataKey="name" />
                            <YAxis
                                label={{
                                    value: `${metric.name} (${metric.unit})`,
                                    angle: -90,
                                    position: 'insideLeft',
                                    offset: -5
                                }}
                            />
                            <Tooltip content={<CustomTooltip />} />
                            <Legend />
                            <Bar
                                dataKey="idle"
                                name="Idle State"
                                fill={metric.color.idle}
                            />
                            <Bar
                                dataKey="load"
                                name="Under Load"
                                fill={metric.color.load}
                            />
                        </BarChart>
                    </ResponsiveContainer>
                </div>
            </div>
        );
    };

    if (!engines.length) {
        return (
            <div className="bg-white rounded-lg shadow-lg p-6">
                <h2 className="text-xl font-bold mb-4">Performance Metrics</h2>
                <p>No performance data available</p>
            </div>
        );
    }

    return (
        <div className="bg-white rounded-lg shadow-lg p-6">
            <div className="flex justify-between items-center mb-6">
                <h2 className="text-xl font-bold">Performance Metrics</h2>
                <div className="text-sm text-gray-500">
                    Comparing Idle vs Load States
                </div>
            </div>

            {metrics.map(metric => (
                <MetricChart key={metric.key} metric={metric} />
            ))}

            <div className="mt-4 text-sm text-gray-500">
                <p>Available engines: {engines.join(', ')}</p>
                <p>Each metric shows resource usage in idle state and under load</p>
            </div>
        </div>
    );
}

// Главный компонент приложения
function DockerPerformance() {
    const [startupData, setStartupData] = useState([]);
    const [buildData, setBuildData] = useState({});
    const [performanceData, setPerformanceData] = useState({ idle: {}, load: {} });
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState(null);

    async function loadStartupData() {
        const engines = ['colima', 'docker-desktop', 'podman-desktop', 'rancher-desktop', 'orbstack'];
        const results = [];

        for (const engine of engines) {
            try {
                const response = await fetch(`../results/startup/${engine}_startup.json`);
                if (response.ok) {
                    const jsonData = await response.json();
                    results.push(jsonData);
                }
            } catch (error) {
                console.log(`No data for ${engine}`);
            }
        }

        return results;
    }

    async function loadBuildData() {
        const engines = ['colima', 'docker-desktop', 'podman-desktop', 'rancher-desktop', 'orbstack'];
        const testTypes = ['java', 'ml', 'simple']; // список ваших тестов
        const results = {};

        for (const engine of engines) {
            try {
                results[engine] = [];

                for (const testType of testTypes) {
                    try {
                        const response = await fetch(`../results/build/${engine}/${testType}_result.json`);
                        if (response.ok) {
                            const data = await response.json();
                            results[engine].push(data);
                        }
                    } catch (e) {
                        console.log(`No ${testType} test for ${engine}`);
                    }
                }

                // Если для движка нет ни одного результата, удаляем его из итогового объекта
                if (results[engine].length === 0) {
                    delete results[engine];
                }
            } catch (error) {
                console.log(`Error loading data for ${engine}:`, error);
            }
        }

        return results;
    }

    async function loadPerformanceData() {
        const engines = ['colima', 'docker-desktop', 'podman-desktop', 'rancher-desktop', 'orbstack'];
        const results = {
            idle: {},
            load: {}
        };

        for (const engine of engines) {
            try {
                // Загружаем idle метрики
                const idleResponse = await fetch(`../results/performance/${engine}_idle_resources.json`);
                if (idleResponse.ok) {
                    const idleData = await idleResponse.json();
                    if (idleData && idleData.metrics) {
                        results.idle[engine] = idleData.metrics;
                    }
                }

                // Загружаем load метрики
                const loadResponse = await fetch(`../results/performance/${engine}_load_resources.json`);
                if (loadResponse.ok) {
                    const loadData = await loadResponse.json();
                    if (loadData && loadData.metrics) {
                        results.load[engine] = loadData.metrics;
                    }
                }
            } catch (error) {
                console.log(`Error loading performance data for ${engine}:`, error);
            }
        }

        return results;
    }

    useEffect(() => {
        const fetchData = async () => {
            try {
                const [startup, build, performance] = await Promise.all([
                    loadStartupData(),
                    loadBuildData(),
                    loadPerformanceData()
                ]);
                setStartupData(startup);
                setBuildData(build);
                setPerformanceData(performance);
                setError(null);
            } catch (err) {
                setError('Ошибка загрузки данных');
                console.error('Error:', err);
            } finally {
                setLoading(false);
            }
        };

        fetchData();
        const interval = setInterval(fetchData, 5 * 60 * 1000);
        return () => clearInterval(interval);
    }, []);

    if (loading) {
        return (
            <div className="flex justify-center items-center h-screen">
                <div className="text-xl">Loading...</div>
            </div>
        );
    }

    if (error) {
        return (
            <div className="flex justify-center items-center h-screen text-red-600">
                <div className="text-xl">{error}</div>
            </div>
        );
    }

    return (
        <div className="container mx-auto p-4">
            <h1 className="text-2xl font-bold mb-6">Docker Engine Performance Dashboard</h1>
            <StartupPerformance data={startupData} />
            <div className="mb-6"></div>
            <BuildPerformance data={buildData} />
            <div className="mb-6"></div>
            <PerformanceMetrics data={performanceData} />
            <div className="mt-4 text-sm text-gray-500">
                <p>Last updated: {new Date().toLocaleString()}</p>
            </div>
        </div>
    );
}

ReactDOM.render(
    <DockerPerformance/>,
    document.getElementById('root')
);