#define FACTOR 1.2

extern vec2 screen_size;
extern number elapsed_time;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    number x_coord = ((screen_coords.x / screen_size.x) - 0.5) * (1.6) * (screen_size.x/screen_size.y);
    x_coord *= x_coord;
    x_coord *= -x_coord;
    x_coord += 1;
    number y_coord = ((screen_coords.y / screen_size.y) - 0.5) * 2;
    y_coord *= y_coord;
    y_coord *= -y_coord;
    y_coord += 1;
    
    vec4 textCol = Texel(texture, texture_coords);
    
    color = (color * (((x_coord * y_coord) * 0.3) + 0.7)) + (sin((elapsed_time * 20) + (screen_coords.y / screen_size.y * 600)) * 0.04);
    
    return color * textCol;
}