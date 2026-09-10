#ifndef PLAYER_HPP
#define PLAYER_HPP

#include <godot_cpp/classes/character_body2d.hpp>

namespace godot {

    class Player : public CharacterBody2D {
        GDCLASS(Player, CharacterBody2D)

    private:
        double speed = 300.0;
        double jump_velocity = -400.0; // Valores negativos vão para CIMA na 2D

    protected:
        static void _bind_methods();

    public:
        Player();
        ~Player();

        void _physics_process(double delta) override;

        // Getters e Setters para as variáveis
        void set_speed(const double p_speed);
        double get_speed() const;

        void set_jump_velocity(const double p_jump_velocity);
        double get_jump_velocity() const;
    };

}

#endif
