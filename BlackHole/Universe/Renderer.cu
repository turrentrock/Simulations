#include <CudaVector.cuh>
#include <Universe/Renderer.cuh>

// #define GRAVITY

#define PI 3.1415926535897932384626433832795

#define MAX_DIST        100.
#define MAX_STEPS       5000
#define SURF_DIST       .01

__device__ float clamp(float y , float a, float b ) {
	return (y > b ? b : y) < a ? a  : y ;
}

__device__ float Torus(vec3 p,vec2 r) {
	float x = vec2(p.x(),p.z()).length() - r.x();

	return vec2(x,p.y()).length() - r.y();
}

__device__ float Sphere(vec3 p,vec3 o,float r) {
	return (p - vec3(o.x(),o.y(),o.z())).length() - r;
}

__device__ float HorizontalPlaneThroughOrigin(vec3 p) {
	return p.y();
}


__device__ float GetDist(vec3 p){

	float sphereBHDist = Sphere(p,vec3(0.0f,0.0f,0.0f),.5f);
 	float sphereDist = Sphere(p,vec3(-1.2f,0.0f,-1.2f),.2f);
 	float planeDist = HorizontalPlaneThroughOrigin(p);
 	float torusDist = Torus(p,vec2(1.0f,.08f));

 	#ifdef GRAVITY
	 	float d = fminf(sphereDist,torusDist);
	#else
	 	float d;
	 	d = fminf(sphereBHDist,torusDist);
	 	d = fminf(sphereDist,d);
	#endif

 	return d;

}

__device__ float RayMarch(vec3 ro,vec3 rd){
	float dO = 0;

	for(int i=0;i<MAX_STEPS;i++){
		vec3 p = ro+rd*vec3(dO,dO,dO);
		float dS = GetDist(p);
		dO += dS;
		if(dO > MAX_DIST || dS < SURF_DIST) break;
	}

	return dO;
} 

__device__ int RayMarchWithGravity(vec3 ro,vec3 rd){

	rd = unit_vector(rd);
	vec3 black_hole_center = vec3(0.0f,0.0f,0.0f);
	float G = 5.0f;
	float black_hole_mass = 1.0f;
	float speed_of_light = 5.0f;
	float dt = .001f;

	float distance_travelled = 0.0f;

	for(int i=0;i<MAX_STEPS;i++){
		vec3 force_direction = unit_vector(black_hole_center - ro);
		float distance_btwn = (black_hole_center - ro).length();

		// Update direction
		vec3 acc  =  force_direction * G * black_hole_mass / distance_btwn / distance_btwn;
		rd = unit_vector(rd * speed_of_light + acc * dt);

		// Update position
		ro = ro + rd * speed_of_light * dt;

		distance_travelled += (rd * speed_of_light * dt).length();

		float closest_distance = GetDist(ro);
		if (closest_distance < SURF_DIST) return 1;
		if (distance_travelled > MAX_DIST) return 0;
			
	}

	return 0;

} 

__device__ vec3 GetNormal(vec3 p){
	float d = GetDist(p);
	vec2 e = vec2(0.01f,0.f);

	vec3 n = vec3(d,d,d)- vec3(
				GetDist(p-vec3(e.x(),e.y(),e.y())),
				GetDist(p-vec3(e.y(),e.x(),e.y())),
				GetDist(p-vec3(e.y(),e.y(),e.x()))
			);

	return unit_vector(n);
}

__device__ float GetLight(vec3 p){
	vec3 lightPosition = vec3(0.f,5.f,6.f);

	vec3 l = unit_vector(lightPosition-p);
	vec3 n = GetNormal(p);

	float diff = clamp(dot(n,l),0.f,1.f);

	float d = RayMarch(p+n*SURF_DIST*1.2f,l);
	if (d<(lightPosition-p).length()) diff *= .1f;

	return diff;
}

__global__ void Render(DeviceCamera **d_camera_ptr,vec3 *d_fb,UniformsList l) {

	DeviceCamera* d_camera = *d_camera_ptr;

	float i = threadIdx.x + blockIdx.x * blockDim.x;
	float j = threadIdx.y + blockIdx.y * blockDim.y;

	if((i >= d_camera -> d_width) || (j >= d_camera -> d_height)) return;

	int pixel_index = j*(d_camera -> d_width) + i;

	vec2 fragCoords = vec2(i,j);
	vec2 uv = (fragCoords-.5*(*l.u_resolution))/(l.u_resolution->y());

	float time = *(l.u_time) / 10000.;

	/*camera start*/
	float zoom = 1.;
	#if 1
		vec3 ro = vec3(3.,10.*sin(time),3.);
	#else
		vec3 ro = vec3(3.*cos(time),0.,3.*sin(time));
	#endif
	vec3 lookat = vec3(0.,0.,0.);
	vec3 u_world = vec3(0.,1.,0.);
	vec3 f = unit_vector(lookat-ro);
	vec3 r = cross(u_world,f);
	vec3 u = cross(f,r);

	vec3 c = ro + f*zoom;
	vec3 k = c + uv.x()*r + uv.y()*u;

	vec3 rd = unit_vector(k-ro);
	/*camera end*/


	#ifdef GRAVITY
		/* WithGravity Ray march */
		float ans = RayMarchWithGravity(ro,rd);
		d_fb[pixel_index] = vec3(1.0f,1.0f,1.0f)*ans;
		
	#else
		/* Standerd Ray march */
		float d = RayMarch(ro,rd);
		vec3 p = ro+rd*d;
		float diff = GetLight(p);
		d_fb[pixel_index] = vec3(diff,diff,diff);

	#endif
}


