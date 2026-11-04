package com.prmteam7.podcasthistory.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class ApiMutationRealtimeConfig implements WebMvcConfigurer {
    private final ApiMutationRealtimeInterceptor interceptor;

    public ApiMutationRealtimeConfig(ApiMutationRealtimeInterceptor interceptor) {
        this.interceptor = interceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(interceptor).addPathPatterns("/api/**");
    }
}
