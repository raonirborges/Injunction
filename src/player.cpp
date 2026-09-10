#include "player.hpp"
#include <godot_cpp/classes/input.hpp>

using namespace godot;

void Player::_bind_methods() {
    // Registra os métodos Getters e Setters
    ClassDB::bind_method(D_METHOD("get_speed"), &Player::get_speed);
    ClassDB::bind_method(D_METHOD("set_speed", "p_speed"), &Player::set_speed);
    ClassDB::bind_method(D_METHOD("get_jump_velocity"), &Player::get_jump_velocity);
    ClassDB::bind_method(D_METHOD("set_jump_velocity", "p_jump_velocity"), &Player::set_jump_velocity);

    // Expõe as propriedades no Inspetor do Godot
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "speed"), "set_speed", "get_speed");
    ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "jump_velocity"), "set_jump_velocity", "get_jump_velocity");
}

Player::Player() {}
Player::~Player() {}

void Player::set_speed(const double p_speed) {
    speed = p_speed;
}

double Player::get_speed() const {
    return speed;
}

void Player::set_jump_velocity(const double p_jump_velocity) {
    jump_velocity = p_jump_velocity;
}

double Player::get_jump_velocity() const {
    return jump_velocity;
}

void Player::_physics_process(double delta) {
    Vector2 velocity = get_velocity();

    // Aplica gravidade
    if (!is_on_floor()) {
        velocity.y += get_gravity().y * delta;
    }

    Input *input = Input::get_singleton();

    // Pulo (com a variável jump_velocity flexível)
    if (input->is_action_just_pressed("ui_accept") && is_on_floor()) {
        velocity.y = jump_velocity;
    }

    // Movimentação Horizontal (com a variável speed flexível)
    double direction = input->get_axis("ui_left", "ui_right");
    if (direction != 0) {
        velocity.x = direction * speed;
    } else {
        velocity.x = 0;
    }

    set_velocity(velocity);
    move_and_slide();
}
