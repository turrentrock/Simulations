#ifndef SIMULATION_GAME_OF_LIFE_CELL_MAP_FACTORY_HPP_
#define SIMULATION_GAME_OF_LIFE_CELL_MAP_FACTORY_HPP_

#include <string>

#include <CellMap/CellMap.hpp>
#include <CellMap/CPU/CellMapCPU.hpp>
#include <CellMap/GPU/CellMapCuda.cuh>
#include <CellMap/GPU/CellMapOpenCL.hpp>

struct CellMapFactoryConfig {
	std::string implementation;
	int width;
	int height;
	bool edge_wrap;
};

CellMap* CellMapFactory(CellMapFactoryConfig& config);

#endif /*SIMULATION_GAME_OF_LIFE_CELL_MAP_FACTORY_HPP_*/