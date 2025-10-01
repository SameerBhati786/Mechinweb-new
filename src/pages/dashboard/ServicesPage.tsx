import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { 
  ShoppingCart, 
  Search, 
  Filter, 
  Star, 
  Clock, 
  CheckCircle,
  ArrowRight,
  Zap,
  Shield,
  Users
} from 'lucide-react';
import { ServiceManager, ServiceData } from '../../lib/services';
import { getPreferredCurrency, formatCurrency, convertCurrency } from '../../utils/currency';
import ErrorBoundary from '../../components/ErrorBoundary';

const ServicesPage = () => {
  const [isVisible, setIsVisible] = useState(false);
  const [services, setServices] = useState<ServiceData[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [userCurrency, setUserCurrency] = useState('USD');
  const [convertedPricing, setConvertedPricing] = useState<{ [serviceId: string]: any }>({});

  useEffect(() => {
    setIsVisible(true);
    initializeServices();
  }, []);

  const initializeServices = async () => {
    try {
      console.log('Loading services from database...');
      
      // Get user's preferred currency
      const currency = await getPreferredCurrency();
      setUserCurrency(currency);
      
      // Load services from database
      const servicesData = await ServiceManager.getAllServices();
      console.log('Services loaded:', servicesData);
      setServices(servicesData);
      
      // Convert pricing if needed
      if (currency !== 'USD') {
        const conversions: { [serviceId: string]: any } = {};
        
        for (const service of servicesData) {
          if (service.pricing) {
            const servicePricing: any = {};
            for (const [tier, price] of Object.entries(service.pricing as Record<string, number>)) {
              if (price && typeof price === 'number') {
                servicePricing[tier] = await convertCurrency(price, 'USD', currency);
              }
            }
            conversions[service.id] = servicePricing;
          }
        }
        
        setConvertedPricing(conversions);
        console.log('Pricing converted for currency:', currency);
      }
    } catch (error) {
      console.error('Error loading services:', error);
    } finally {
      setLoading(false);
    }
  };

  const getServicePrice = (service: ServiceData, tier: string) => {
    if (userCurrency === 'USD') {
      return (service.pricing as Record<string, number>)?.[tier] || 0;
    }
    return convertedPricing[service.id]?.[tier] || (service.pricing as Record<string, number>)?.[tier] || 0;
  };

  const getLowestPrice = (service: ServiceData) => {
    const pricing = userCurrency === 'USD' ? service.pricing : convertedPricing[service.id];
    if (!pricing) return 0;
    
    const prices = Object.values(pricing as Record<string, number>).filter(price => price && price > 0);
    return Math.min(...(prices as number[]));
  };

  const categories = ['all', ...new Set(services.map(service => service.category))];

  const filteredServices = services.filter(service => {
    const matchesSearch = service.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                         service.description.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesCategory = categoryFilter === 'all' || service.category === categoryFilter;
    return matchesSearch && matchesCategory;
  });

  return (
    <ErrorBoundary>
      <div className="space-y-8">
        {/* Header */}
        <div className={`transition-all duration-1000 ${isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'}`}>
          <div className="flex flex-col md:flex-row md:items-center md:justify-between">
            <div>
              <h1 className="text-3xl font-bold text-white mb-2">Purchase Services</h1>
              <p className="text-gray-400 text-lg">Choose from our professional IT services</p>
            </div>
            <div className="mt-4 md:mt-0">
              <div className="flex items-center space-x-2 text-sm text-gray-400">
                <Shield className="w-4 h-4 text-cyan-400" />
                <span>Showing prices in {userCurrency}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Search and Filters */}
        <div className={`bg-gray-800/50 backdrop-blur-sm rounded-2xl p-6 border border-gray-700/50 transition-all duration-1000 delay-200 ${isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'}`}>
          <div className="flex flex-col md:flex-row gap-4">
            <div className="flex-1 relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <input
                type="text"
                placeholder="Search services..."
                value={searchTerm}
                onChange={(e) => setSearchTerm(e.target.value)}
                className="w-full pl-10 pr-4 py-3 bg-gray-700/50 border border-gray-600 rounded-xl text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent"
              />
            </div>
            <div className="relative">
              <Filter className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400 w-5 h-5" />
              <select
                value={categoryFilter}
                onChange={(e) => setCategoryFilter(e.target.value)}
                className="pl-10 pr-8 py-3 bg-gray-700/50 border border-gray-600 rounded-xl text-white focus:outline-none focus:ring-2 focus:ring-cyan-500 focus:border-transparent appearance-none cursor-pointer"
              >
                {categories.map(category => (
                  <option key={category} value={category}>
                    {category === 'all' ? 'All Categories' : category}
                  </option>
                ))}
              </select>
            </div>
          </div>
        </div>

        {/* Services Grid */}
        <div className={`transition-all duration-1000 delay-400 ${isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'}`}>
          {loading ? (
            <div className="text-center py-12">
              <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-cyan-500 mx-auto mb-4"></div>
              <p className="text-white">Loading services...</p>
            </div>
          ) : filteredServices.length === 0 ? (
            <div className="text-center py-12">
              <ShoppingCart className="w-16 h-16 text-gray-600 mx-auto mb-4" />
              <h3 className="text-xl font-semibold text-white mb-2">No Services Found</h3>
              <p className="text-gray-400">
                {searchTerm || categoryFilter !== 'all' 
                  ? 'No services match your current filters.' 
                  : 'No services available at the moment.'}
              </p>
            </div>
          ) : (
            <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
              {filteredServices.map((service, index) => (
                <div
                  key={service.id}
                  className="group bg-gray-800/50 backdrop-blur-sm rounded-2xl overflow-hidden border border-gray-700/50 hover:border-cyan-500/50 transition-all duration-500 transform hover:scale-105 hover:shadow-2xl hover:shadow-cyan-500/20"
                >
                  {/* Service Header */}
                  <div className="p-6 border-b border-gray-700/50">
                    <div className="flex items-center justify-between mb-4">
                      <div className="p-3 bg-gradient-to-r from-cyan-500 to-purple-600 rounded-xl">
                        <Zap className="h-6 w-6 text-white" />
                      </div>
                      <div className="text-right">
                        <div className="text-sm text-gray-400">Starting from</div>
                        <div className="text-xl font-bold text-cyan-400">
                          {formatCurrency(getLowestPrice(service), userCurrency)}
                        </div>
                      </div>
                    </div>
                    
                    <h3 className="text-xl font-bold text-white mb-3 group-hover:text-cyan-400 transition-colors duration-300">
                      {service.name}
                    </h3>
                    
                    <p className="text-gray-300 mb-4 leading-relaxed">
                      {service.description}
                    </p>
                    
                    <div className="flex items-center space-x-4 text-sm text-gray-400">
                      <div className="flex items-center space-x-1">
                        <Star className="h-4 w-4 text-yellow-400" />
                        <span>4.9/5</span>
                      </div>
                      <div className="flex items-center space-x-1">
                        <Clock className="h-4 w-4 text-green-400" />
                        <span>24-48h delivery</span>
                      </div>
                    </div>
                  </div>

                  {/* Features */}
                  <div className="p-6">
                    <h4 className="text-white font-semibold mb-3">Key Features:</h4>
                    <div className="space-y-2 mb-6">
                      {((service.features as Record<string, string[]>)?.basic || []).slice(0, 3).map((feature: string, featureIndex: number) => (
                        <div key={featureIndex} className="flex items-center space-x-2">
                          <CheckCircle className="h-4 w-4 text-green-400 flex-shrink-0" />
                          <span className="text-gray-300 text-sm">{feature}</span>
                        </div>
                      ))}
                    </div>
                    
                    <Link
                      to={`/client/purchase/${service.id}`}
                      className="group/btn w-full bg-gradient-to-r from-cyan-500 to-purple-600 text-white px-6 py-3 rounded-xl font-semibold hover:from-cyan-600 hover:to-purple-700 transition-all duration-300 transform hover:scale-105 shadow-lg hover:shadow-xl inline-flex items-center justify-center space-x-2"
                    >
                      <span>Purchase Service</span>
                      <ArrowRight className="h-4 w-4 group-hover/btn:translate-x-1 transition-transform duration-300" />
                    </Link>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {/* Service Categories Overview */}
        {!loading && services.length > 0 && (
          <div className={`transition-all duration-1000 delay-600 ${isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'}`}>
            <div className="bg-gray-800/50 backdrop-blur-sm rounded-2xl p-8 border border-gray-700/50">
              <h2 className="text-2xl font-bold text-white mb-6">Service Categories</h2>
              <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-6">
                {categories.filter(cat => cat !== 'all').map((category, index) => {
                  const categoryServices = services.filter(s => s.category === category);
                  const categoryIcon = getCategoryIcon(category);
                  
                  return (
                    <div key={category} className="bg-gray-700/30 rounded-xl p-4 hover:bg-gray-700/50 transition-colors">
                      <div className="flex items-center space-x-3 mb-3">
                        {categoryIcon}
                        <h3 className="text-white font-semibold capitalize">{category}</h3>
                      </div>
                      <p className="text-gray-400 text-sm mb-2">
                        {categoryServices.length} service{categoryServices.length !== 1 ? 's' : ''} available
                      </p>
                      <button
                        onClick={() => setCategoryFilter(category)}
                        className="text-cyan-400 hover:text-cyan-300 text-sm font-medium"
                      >
                        View Services →
                      </button>
                    </div>
                  );
                })}
              </div>
            </div>
          </div>
        )}

        {/* Help Section */}
        <div className={`transition-all duration-1000 delay-800 ${isVisible ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-10'}`}>
          <div className="bg-gradient-to-r from-cyan-500/10 to-purple-500/10 rounded-2xl p-8 border border-cyan-500/20">
            <div className="text-center">
              <h3 className="text-2xl font-bold text-white mb-4">
                Need Help Choosing?
              </h3>
              <p className="text-gray-300 mb-6 max-w-2xl mx-auto">
                Not sure which service is right for you? Our experts can help you choose 
                the perfect solution for your specific needs.
              </p>
              <div className="flex flex-col sm:flex-row gap-4 justify-center">
                <Link
                  to="/#contact"
                  className="bg-gradient-to-r from-cyan-500 to-purple-600 text-white px-8 py-3 rounded-xl font-semibold hover:from-cyan-600 hover:to-purple-700 transition-all duration-300 transform hover:scale-105 shadow-lg hover:shadow-xl inline-flex items-center space-x-2"
                >
                  <span>Get Expert Advice</span>
                  <ArrowRight className="h-4 w-4" />
                </Link>
                <a
                  href="https://wa.me/15551234567?text=Hi%20Mechinweb,%20I%20need%20help%20choosing%20the%20right%20IT%20service."
                  target="_blank"
                  rel="noopener noreferrer"
                  className="border border-cyan-500 text-cyan-400 hover:bg-cyan-500 hover:text-white px-8 py-3 rounded-xl font-semibold transition-all duration-300 transform hover:scale-105 inline-flex items-center space-x-2"
                >
                  <span>WhatsApp Chat</span>
                  <ArrowRight className="h-4 w-4" />
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>
    </ErrorBoundary>
  );
};

const getCategoryIcon = (category: string) => {
  switch (category.toLowerCase()) {
    case 'email':
    case 'email migration':
    case 'email security':
      return <Shield className="w-5 h-5 text-cyan-400" />;
    case 'ssl':
    case 'security':
      return <Shield className="w-5 h-5 text-green-400" />;
    case 'cloud':
    case 'cloud management':
      return <Users className="w-5 h-5 text-blue-400" />;
    case 'hosting':
    case 'support':
      return <Zap className="w-5 h-5 text-orange-400" />;
    default:
      return <Zap className="w-5 h-5 text-purple-400" />;
  }
};

export default ServicesPage;